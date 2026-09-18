;;; doom-tree-slide.el --- A Doom-friendly presentation mode -*- lexical-binding: t; -*-

;; Author: Alexandre Moreno
;; Version: 3.5.0
;; Package-Requires: ((emacs "27.1") (org-tree-slide "2.8"))

;;; Commentary:
;; A minimalistic, Doom-friendly wrapper around org-tree-slide.

;;; Code:

(require 'org-tree-slide)

(defcustom doom-tree-slide-text-scale 2
  "How much to scale text during presentations."
  :type 'integer)

(defcustom doom-tree-slide-margin-width 10
  "Fixed number of columns to use as left/right margins."
  :type 'integer)

(defcustom doom-tree-slide-top-margin 2
  "Number of blank lines to push the slide down."
  :type 'integer)

(setq org-tree-slide-skip-outline-level 2
      org-tree-slide-never-touch-face t
      org-tree-slide-slide-in-effect nil
      org-tree-slide-slide-in-blank-lines 0
      org-tree-slide-modeline-display nil
      org-tree-slide-header nil
      org-tree-slide-heading-emphasis nil)

(when (bound-and-true-p evil-mode)
  (evil-define-minor-mode-key 'normal 'doom-tree-slide-mode
    (kbd "h") #'org-tree-slide-move-previous-tree
    (kbd "k") #'org-tree-slide-move-previous-tree
    (kbd "l") #'org-tree-slide-move-next-tree
    (kbd "j") #'org-tree-slide-move-next-tree))

(defvar-local doom-tree-slide--saved-cursor nil)
(defvar-local doom-tree-slide--saved-evil-cursor nil)
(defvar-local doom-tree-slide--saved-line-numbers nil)
(defvar-local doom-tree-slide--saved-hl-line nil)
(defvar-local doom-tree-slide--saved-mode-line nil)
(defvar-local doom-tree-slide--saved-tilde-fringe nil)
(defvar-local doom-tree-slide--top-margin-ov nil)
(defvar-local doom-tree-slide--slide-number-string "")

(defun doom-tree-slide--apply-top-margin ()
  (when doom-tree-slide--top-margin-ov
    (delete-overlay doom-tree-slide--top-margin-ov))
  (when (and doom-tree-slide-mode (> doom-tree-slide-top-margin 0))
    (setq doom-tree-slide--top-margin-ov (make-overlay (point-min) (point-min)))
    (overlay-put doom-tree-slide--top-margin-ov 'before-string
                 (make-string doom-tree-slide-top-margin ?\n))))

(defun doom-tree-slide--clear-overlays ()
  (save-restriction
    (widen)
    (remove-overlays (point-min) (point-max) 'doom-tree-slide-overlay t)))

(defun doom-tree-slide--apply-hiding-overlays ()
  (doom-tree-slide--clear-overlays)
  (save-excursion
    (save-restriction
      (widen)
      (goto-char (point-min))
      (while (re-search-forward "^\\(\\*+\\)\\s-+" nil t)
        (let ((ov (make-overlay (match-beginning 1) (match-end 0))))
          (overlay-put ov 'display "")
          (overlay-put ov 'doom-tree-slide-overlay t)))

      (goto-char (point-min))
      (let ((case-fold-search t))
        (while (re-search-forward "^[ \t]*#\\+\\(begin\\|end\\)_src.*$" nil t)
          (let* ((end (match-end 0))
                 (end (if (eq (char-after end) ?\n) (1+ end) end))
                 (ov (make-overlay (line-beginning-position) end)))
            (overlay-put ov 'display "")
            (overlay-put ov 'doom-tree-slide-overlay t))))

      (goto-char (point-min))
      (let ((case-fold-search t))
        (while (re-search-forward "^[ \t]*#\\+begin_notes" nil t)
          (let ((beg (line-beginning-position)))
            (when (re-search-forward "^[ \t]*#\\+end_notes.*$" nil t)
              (let* ((end (match-end 0))
                     (end (if (eq (char-after end) ?\n) (1+ end) end))
                     (ov (make-overlay beg end)))
                (overlay-put ov 'display "")
                (overlay-put ov 'doom-tree-slide-overlay t)))))))))

(defun doom-tree-slide--sync-windows ()
  (let ((top (point-min)))
    (walk-windows
     (lambda (win)
       (when (eq (window-buffer win) (current-buffer))
         (set-window-point win top)))
     nil t)))

(defun doom-tree-slide--update-slide-number ()
  (let* ((pos (point-min))
         (current 1)
         (total 0))
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (while (re-search-forward "^\\* " nil t)
          (setq total (1+ total))
          (when (<= (match-beginning 0) pos)
            (setq current total)))))
    (setq doom-tree-slide--slide-number-string (format "Slide %d of %d" current total))
    (force-mode-line-update)))

(defun doom-tree-slide--quiet-move (orig-fn &rest args)
  (let ((inhibit-message t))
    (apply orig-fn args))
  (doom-tree-slide--update-slide-number))

(defun doom-tree-slide--apply-margins (&rest _)
  (when (and doom-tree-slide-mode (current-buffer))
    (walk-windows
     (lambda (win)
       (when (eq (window-buffer win) (current-buffer))
         (set-window-margins win
                             doom-tree-slide-margin-width
                             doom-tree-slide-margin-width)))
     nil t)))

(defun doom-tree-slide--remove-margins ()
  (walk-windows
   (lambda (win)
     (when (eq (window-buffer win) (current-buffer))
       (set-window-margins win nil nil)))
   nil t))

(defun doom-tree-slide--sync-teleprompter ()
  (let ((notes-buf (get-buffer "*Presenter Notes*"))
        (notes-text ""))
    (when notes-buf
      (save-excursion
        (goto-char (point-min))
        (let ((case-fold-search t))
          (when (re-search-forward "^[ \t]*#\\+begin_notes[ \t]*\n" nil t)
            (let ((start (point)))
              (when (re-search-forward "^[ \t]*#\\+end_notes" nil t)
                (setq notes-text (buffer-substring-no-properties start (match-beginning 0))))))))

      (with-current-buffer notes-buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (if (string-empty-p (string-trim notes-text))
                      "\n  (No notes for this slide)"
                    notes-text))
          (goto-char (point-min)))))))

;;;###autoload
(defun doom-tree-slide-presenter-notes ()
  "Spawn the presenter notes natively."
  (interactive)
  (let ((buf (get-buffer-create "*Presenter Notes*")))
    (with-current-buffer buf
      (visual-line-mode 1)
      (read-only-mode 1))

    (delete-other-windows)
    (doom-tree-slide--sync-teleprompter)

    (let ((window-min-height 1)
          (window-safe-min-height 1))
      (display-buffer buf
                      '((display-buffer-below-selected)
                        (window-height . 0.3))))

    (doom-tree-slide--apply-margins)
    (message "Presenter view ready!")))

;;;###autoload
(define-minor-mode doom-tree-slide-mode
  "A minimalistic wrapper for org-tree-slide."
  :init-value nil
  :global nil
  (if doom-tree-slide-mode
      (progn
        (when (and (bound-and-true-p centered-window-mode)
                   (fboundp 'centered-window-mode))
          (centered-window-mode -1))

        (setq doom-tree-slide--saved-cursor cursor-type
              doom-tree-slide--saved-line-numbers display-line-numbers
              doom-tree-slide--saved-hl-line (bound-and-true-p hl-line-mode)
              doom-tree-slide--saved-mode-line mode-line-format
              doom-tree-slide--saved-tilde-fringe (bound-and-true-p vi-tilde-fringe-mode))

        (when (bound-and-true-p evil-mode)
          (setq doom-tree-slide--saved-evil-cursor evil-normal-state-cursor)
          (set (make-local-variable 'evil-normal-state-cursor) nil))

        (when doom-tree-slide--saved-hl-line
          (hl-line-mode -1))

        ;; Hide Vim ~ tildes
        (when doom-tree-slide--saved-tilde-fringe
          (vi-tilde-fringe-mode -1))

        (set (make-local-variable 'display-line-numbers) nil)
        (set (make-local-variable 'cursor-type) nil)

        (doom-tree-slide--update-slide-number)
        (set (make-local-variable 'mode-line-format)
             '(:eval
               (let ((margin (max 0 (or (car (window-margins)) doom-tree-slide-margin-width))))
                 (concat (make-string margin ?\s)
                         (propertize doom-tree-slide--slide-number-string 'face 'shadow)))))

        (org-tree-slide-mode 1)
        (text-scale-set doom-tree-slide-text-scale)

        (doom-tree-slide--apply-margins)
        (doom-tree-slide--apply-top-margin)

        (add-hook 'window-size-change-functions #'doom-tree-slide--apply-margins nil t)
        (add-hook 'org-tree-slide-after-narrow-hook #'doom-tree-slide--apply-top-margin nil t)
        (add-hook 'org-tree-slide-after-narrow-hook #'doom-tree-slide--sync-teleprompter nil t)
        (add-hook 'org-tree-slide-after-narrow-hook #'doom-tree-slide--sync-windows nil t)

        (doom-tree-slide--apply-hiding-overlays)

        (advice-add 'org-tree-slide-move-next-tree :around #'doom-tree-slide--quiet-move)
        (advice-add 'org-tree-slide-move-previous-tree :around #'doom-tree-slide--quiet-move))

    ;; TEARDOWN
    (text-scale-set 0)
    (org-tree-slide-mode -1)

    (doom-tree-slide--clear-overlays)
    (when doom-tree-slide--top-margin-ov
      (delete-overlay doom-tree-slide--top-margin-ov))

    (let ((notes-buf (get-buffer "*Presenter Notes*")))
      (when notes-buf
        (let ((win (get-buffer-window notes-buf t)))
          (when win (delete-window win)))
        (kill-buffer notes-buf)))

    (doom-tree-slide--remove-margins)

    (remove-hook 'window-size-change-functions #'doom-tree-slide--apply-margins t)
    (remove-hook 'org-tree-slide-after-narrow-hook #'doom-tree-slide--apply-top-margin t)
    (remove-hook 'org-tree-slide-after-narrow-hook #'doom-tree-slide--sync-teleprompter t)
    (remove-hook 'org-tree-slide-after-narrow-hook #'doom-tree-slide--sync-windows t)

    ;; Restore states
    (set (make-local-variable 'cursor-type) doom-tree-slide--saved-cursor)
    (set (make-local-variable 'display-line-numbers) doom-tree-slide--saved-line-numbers)
    (set (make-local-variable 'mode-line-format) doom-tree-slide--saved-mode-line)

    (when (bound-and-true-p evil-mode)
      (set (make-local-variable 'evil-normal-state-cursor) doom-tree-slide--saved-evil-cursor))

    (when doom-tree-slide--saved-hl-line
      (hl-line-mode 1))

    (when doom-tree-slide--saved-tilde-fringe
      (vi-tilde-fringe-mode 1))

    (advice-remove 'org-tree-slide-move-next-tree #'doom-tree-slide--quiet-move)
    (advice-remove 'org-tree-slide-move-previous-tree #'doom-tree-slide--quiet-move)

    (when (derived-mode-p 'org-mode)
      (if (fboundp 'org-fold-show-all)
          (org-fold-show-all)
        (org-show-all)))))

(provide 'doom-tree-slide)
;;; doom-tree-slide.el ends here
