# doom-tree-slide

An opinionated wrapper to make `org-tree-slide` play nicely with Doom Emacs.

## What it does

* Maps Evil normal state `h/j/k/l` to slide navigation.
* Uses fixed-column margins to center slides.
* Displays the current slide progress in the echo area.
* Disables cursor, `hl-line-mode` and line numbers while presenting.
* Hides heading asterisks (`*`) , source block delimiters (`#+begin_src`) and
  speaker notes (`#+begin_notes`)
* Speaker notes (see [below](#speaker-notes))

## Doom Emacs Setup

**Add to `packages.el`**

```elisp
(package! doom-tree-slide
  :recipe (:host github :repo "moleike/doom-tree-slide.el"))
```

**Load in `config.el`**

Map the mode to a keybinding of your choice. Example using `SPC t P`:

```elisp
(use-package! doom-tree-slide
  :commands (doom-tree-slide-mode)
  :init
  (map! :leader
        :desc "Toggle Presentation" "t P" #'doom-tree-slide-mode))
```

> [!TIP]
> 
> There is a feature overlap between `doom-tree-slide` and Doom Emacs's default
> `+present` module.
> 
> If you have `(org +present)` enabled in your `init.el` (e.g., to use
> `reveal.js`), you can easily allow both to coexist. Just add the following
> snippet to your `config.el` to remove Doom's default hook for
> `org-tree-slide`. This prevents it from interfering with this mode's custom
> layout:
> 
> 
> ```elisp
> (after! org-tree-slide
>   (remove-hook 'org-tree-slide-mode-hook #'+org-present-prettify-slide-h))
> ```


## Speaker Notes

`doom-tree-slide` provides a teleprompter view for live presentations, allowing
you to read your private notes on your laptop while sharing only the slides on
an external screen.

1. Add notes to your slides:

   ```org
   * My Slide Title
   Slide content goes here.
   
   #+begin_notes
   Your notes
   #+end_notes
   ```

2. Start the presentation by toggling `M-x doom-tree-slide-mode`

3. Clone your frame (`M-x clone-frame`) and drag the new frame to your projector
   or external monitor.

4. Launch presenter mode on your laptop frame by running `M-x
   doom-tree-slide-presenter-notes`. This creates a 70/30 window split that
   automatically syncs your private notes as you change slides.
