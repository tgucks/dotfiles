
" Have j and k navigate visual lines rather than logical ones
nmap j gj
nmap k gk

" Quickly remove search highlights
nmap <F9> :nohl<CR>

" Yank to system clipboard
set clipboard=unnamed

" Go back and forward with Ctrl+O and Ctrl+I
" (make sure to remove default Obsidian shortcuts for these to work)
exmap back obcommand app:go-back
nmap <C-o> :back<CR>
exmap forward obcommand app:go-forward
nmap <C-i> :forward<CR>

" Split panes
exmap splitVertical obcommand workspace:split-vertical
exmap splitHorizontal obcommand workspace:split-horizontal

nmap <C-w>v :splitVertical<CR>
nmap <C-w>h :splitHorizontal<CR>

" tmux-navigator style pane movement
exmap focusLeft obcommand editor:focus-left
exmap focusRight obcommand editor:focus-right
exmap focusUp obcommand editor:focus-top
exmap focusDown obcommand editor:focus-bottom

nmap <C-h> :focusLeft<CR>
nmap <C-j> :focusDown<CR>
nmap <C-k> :focusUp<CR>
nmap <C-l> :focusRight<CR>
