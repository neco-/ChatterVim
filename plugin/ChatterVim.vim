" ==============================================================
" ChatterVim - Chatter client for Vim.
"
" URL: https://github.com/neco-/ChatterVim.git
"   inspired by TwitVim
"     <http://www.vim.org/scripts/script.php?script_id=2204>
"
" TODO:
" 1. add more chatter commands
"    ex.) groups, influence, and so on
" 2. parse feed message using segments
"    ex.) URL, mention, text
" ==============================================================

" Load this module only once.
if exists('loaded_chattervim')
    finish
endif
let loaded_chattervim = 1

" -------------------------------
" command definitions
" -------------------------------
if !exists(':ChatterGetFeeds')
    command! -nargs=0 ChatterGetFeeds :call ChatterVim#ChatterGetFeedsNewsMeFeedItems()
endif
if !exists(':ChatterPostFeeds')
    command! -nargs=0 ChatterPostFeeds :call ChatterVim#ChatterPostFeedsNewsMeFeedItems()
endif
if !exists(':ChatterGetFeedsToMe')
    command! -nargs=0 ChatterGetFeedsToMe :call ChatterVim#ChatterGetFeedsToMeFeedItems()
endif
if !exists(':ChatterGetFeedsCompany')
    command! -nargs=0 ChatterGetFeedsCompany :call ChatterVim#ChatterGetFeedsCompanyFeedItems()
endif

