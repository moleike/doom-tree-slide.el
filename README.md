# doom-tree-slide

An opinionated wrapper to make `org-tree-slide` play nicely with Doom Emacs.

## What it does

* Maps Evil normal state `h/j/k/l` to slide navigation.
* Uses fixed-column margins to center slides.
* Displays the current slide progress in the echo area.
* Disables `hl-line-mode` and line numbers while presenting.
* Hides heading asterisks (`*`) and source block delimiters (`#+begin_src`).

## Doom Emacs Setup

**Add to `packages.el`**

```elisp
(package! doom-tree-slide
  :recipe (:host github :repo "moleike/doom-tree-slide.el"))
```

**Load in `config.el`**

```elisp
(use-package! doom-tree-slide
  :commands (doom-tree-slide-mode)
  :init
  (map! :leader
        :desc "Toggle Presentation" "t P" #'doom-tree-slide-mode))
```

