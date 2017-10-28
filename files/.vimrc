" Don't try to be backwards-compatible with vi
set nocompatible

" Required for Vundle
filetype on
filetype off

" Add Vundle to the runtime path
set rtp+=~/.vim/bundle/Vundle.vim

" Vundle plugins
call vundle#begin()
Plugin 'gmarik/vundle'

Plugin 'tpope/vim-fugitive'
Plugin 'bling/vim-airline'
Plugin 'vim-ruby/vim-ruby'

call vundle#end()


" Powerline configuration
set laststatus=2
set encoding=utf-8
set t_Co=256
let g:airline_powerline_fonts = 1
set ttimeout
set ttimeoutlen=50

filetype plugin indent on


" Line numbering
set relativenumber


" Syntax highlighting
syntax on
set synmaxcol=2048  " disable for long lines

" Tab settings
set tabstop=4 softtabstop=4 shiftwidth=4 expandtab

" Filetype-specific configuration
autocmd FileType ruby,eruby setlocal tabstop=2 softtabstop=2 shiftwidth=2 expandtab
