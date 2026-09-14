;;; doom-tree-slide.el --- A Doom-friendly presentation mode -*- lexical-binding: t; -*-

;; Author: Alexandre Moreno
;; Version: 1.1.4
;; Package-Requires: ((emacs "27.1") (org-tree-slide "2.8"))

;;; Commentary:
;; A minimalistic, Doom-friendly wrapper around org-tree-slide.

;;; Code:

(require 'org-tree-slide)

(defgroup doom-tree-slide nil
  "A simple wrapper for org-tree-slide."
  :group 'org)

(defcustom doom-tree-slide-text-scale 2
  "How much to scale text during presentations."
  :type 'integer)

(defcustom doom-tree-slide-margin-width 5
  "Fixed number of columns to use as margins on the left and right."
  :type 'integer)

(defvar-local doom-tree-slide--saved-cursor nil)
(defvar-local doom-tree-slide--saved-line-numbers nil)
(defvar-local doom-tree-slide--saved-hl-line nil)

(defconst doom-tree-slide--font-lock-keywords
  '(("^\\s-*#\\+begin_.*$" (0 '(face nil display "") t))
    ("^\\s-*#\\+end_.*$"   (0 '(face nil display "") t))
    ("^\\(\\*+\\)\\s-+"    (1 '(face nil display "") t)))
  "Regexes to erase heading asterisks and source block delimiters.")

(defun doom-tree-slide--show-number ()
  "Calculate and display the current slide position."
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
    (message "%d of %d" current total)))

(defun doom-tree-slide--quiet-move (orig-fn &rest args)
  "Mute original echo area output and show a slide counter instead."
  (let ((inhibit-message t))
    (apply orig-fn args))
  (doom-tree-slide--show-number))

(defun doom-tree-slide--apply-margins (&rest _)
  "Apply a fixed-width margin."
  (when doom-tree-slide-mode
    (set-window-margins (selected-window)
                        doom-tree-slide-margin-width
                        doom-tree-slide-margin-width)))

(defun doom-tree-slide--toggle-evil (enable)
  "Set/remove Evil-mode keybindings for slide navigation."
  (when (bound-and-true-p evil-mode)
    (if enable
        (setq-local evil-normal-state-cursor nil)
      (kill-local-variable 'evil-normal-state-cursor))
    (dolist (bind '(("h" . org-tree-slide-move-previous-tree)
                    ("k" . org-tree-slide-move-previous-tree)
                    ("l" . org-tree-slide-move-next-tree)
                    ("j" . org-tree-slide-move-next-tree)))
      (evil-local-set-key 'normal (kbd (car bind))
                          (if enable (cdr bind) nil)))))

;;;###autoload
(define-minor-mode doom-tree-slide-mode
  "A minimalistic wrapper for org-tree-slide."
  :init-value nil
  :global nil
  (if doom-tree-slide-mode
      (progn
        ;; Save states
        (setq-local doom-tree-slide--saved-cursor cursor-type
                    doom-tree-slide--saved-line-numbers display-line-numbers
                    doom-tree-slide--saved-hl-line (bound-and-true-p hl-line-mode))

        (when doom-tree-slide--saved-hl-line
          (hl-line-mode -1))

        (make-local-variable 'font-lock-extra-managed-props)
        (add-to-list 'font-lock-extra-managed-props 'display)

        (font-lock-add-keywords nil doom-tree-slide--font-lock-keywords t)
        (font-lock-flush)

        (setq-local org-tree-slide-skip-outline-level 2
                    org-tree-slide-never-touch-face t
                    org-tree-slide-slide-in-effect nil
                    org-tree-slide-modeline-display nil
                    org-tree-slide-header nil
                    org-tree-slide-heading-emphasis nil
                    display-line-numbers nil
                    cursor-type nil)

        (org-tree-slide-mode 1)
        (text-scale-set doom-tree-slide-text-scale)

        (doom-tree-slide--apply-margins)
        (add-hook 'window-size-change-functions #'doom-tree-slide--apply-margins nil t)

        (doom-tree-slide--toggle-evil t)

        (advice-add 'org-tree-slide-move-next-tree :around #'doom-tree-slide--quiet-move)
        (advice-add 'org-tree-slide-move-previous-tree :around #'doom-tree-slide--quiet-move)

        (doom-tree-slide--show-number))

    ;; Teardown
    (text-scale-set 0)
    (org-tree-slide-mode -1)

    ;; Remove font-lock rules and refresh
    (font-lock-remove-keywords nil doom-tree-slide--font-lock-keywords)
    (setq font-lock-extra-managed-props (remove 'display font-lock-extra-managed-props))
    (font-lock-flush)

    (set-window-margins nil nil nil)
    (remove-hook 'window-size-change-functions #'doom-tree-slide--apply-margins t)

    ;; Restore states
    (setq-local cursor-type doom-tree-slide--saved-cursor
                display-line-numbers doom-tree-slide--saved-line-numbers)

    (when doom-tree-slide--saved-hl-line
      (hl-line-mode 1))

    (doom-tree-slide--toggle-evil nil)

    (advice-remove 'org-tree-slide-move-next-tree #'doom-tree-slide--quiet-move)
    (advice-remove 'org-tree-slide-move-previous-tree #'doom-tree-slide--quiet-move)))

(provide 'doom-tree-slide)
;;; doom-tree-slide.el ends here
