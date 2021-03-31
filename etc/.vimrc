set nocompatible

set history=10000

set number
set ruler

set nowrap

set hlsearch
set incsearch
set showmatch

set cindent
set autoindent
set smartindent

set smarttab
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab

set nobackup
set noswapfile

set fileencoding=utf-8
set fileencodings=utf-8,gbk,gb2312,cp936

set fileformat=unix

"set foldmethod=indent

set backspace=indent,eol,start

set cmdheight=2
set laststatus=2
set statusline=[FILE=%F%m%r%h%w]\ [FORMAT=%{&ff}:%{&fenc!=''?&fenc:&enc}]\ [TYPE=%Y]\ [TOTAL=%L]\ [POS=%l,%v]\ [%p%%]

colorscheme darkblue

filetype on
syntax on
