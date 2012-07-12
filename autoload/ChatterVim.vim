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

" Avoid side-effects from cpoptions setting.
let s:save_cpo = &cpo
set cpo&vim

" ------------------------
" setting
" ------------------------
if !exists('g:chatter_show_comments_num_in_timeline')
    let g:chatter_show_comments_num_in_timeline = 0
endif
if !exists('g:chatter_show_likes_in_timeline')
    let g:chatter_show_likes_in_timeline        = 1
endif
if !exists('g:chatter_show_timeline_num')
    let g:chatter_show_timeline_num             = 20
endif
if !exists('g:chatter_browser_cmd')
    let g:chatter_browser_cmd = ''
endif

if !exists('g:chatter_proxy')
    let g:chatter_proxy = ''
endif

let g:chatter_client_id = '3MVG9QDx8IX8nP5QbdVZkKb85qDNa4sNw8QVdz9F6Psw3vvPPNQDjoudsJ0AYFnyAi6Q21jerT91QfRu_wvQ_'

" ------------------------
" set debug flags
" ------------------------
let s:flag_debug_chatter_vim = 0
if s:flag_debug_chatter_vim == 1
    let s:flag_debug_echo          = 1
    let s:flag_debug_echo_curl_cmd = 1
    let s:flag_debug_echo_result   = 1
    let s:flag_debug_prettyprint   = 0
    let s:debug_prettyprint_filesname = 'ChatterResult_'
else
    let s:flag_debug_echo          = 0
    let s:flag_debug_echo_curl_cmd = 0
    let s:flag_debug_echo_result   = 0
    let s:flag_debug_prettyprint   = 0
    let s:debug_prettyprint_filesname = ''
endif


" ------------------------
" accesser for variables
" ------------------------
function! s:get_chatter_client_id()
    return exists('g:chatter_client_id') ? g:chatter_client_id : ''
endfunction
function! s:get_chatter_proxy()
    return exists('g:chatter_proxy') ? g:chatter_proxy : ''
endfunction

function! s:get_chatter_token_file()
    return exists('g:chatter_token_file') ? g:chatter_token_file : $HOME . "/.chattervim.token"
endfunction
function! s:get_chatter_access_token()
    return exists('g:chatter_access_token') ? g:chatter_access_token : ''
endfunction
function! s:set_chatter_access_token(access_token)
    let g:chatter_access_token = a:access_token
    call s:debug_echo(g:chatter_access_token)
endfunction
function! s:get_chatter_refresh_token()
    return exists('g:chatter_refresh_token') ? g:chatter_refresh_token : ''
endfunction
function! s:set_chatter_refresh_token(refresh_token)
    let g:chatter_refresh_token = a:refresh_token
    call s:debug_echo(g:chatter_refresh_token)
endfunction
function! s:get_chatter_instance_url()
    return exists('g:chatter_instance_url') ? g:chatter_instance_url : ''
endfunction
function! s:set_chatter_instance_url(instance_url)
    let g:chatter_instance_url = a:instance_url
    call s:debug_echo(g:chatter_instance_url)
endfunction

function! s:get_chatter_show_comments_num_in_timeline()
    return exists('g:chatter_show_comments_num_in_timeline') ? g:chatter_show_comments_num_in_timeline : 0
endfunction
function! s:get_chatter_show_likes_in_timeline()
    return exists('g:chatter_show_likes_in_timeline') ? g:chatter_show_likes_in_timeline : 1
endfunction
function! s:get_chatter_show_timeline_num()
    return exists('g:chatter_show_timeline_num') ? g:chatter_show_timeline_num : 20
endfunction

" -------------------------------
" variables
" -------------------------------
let s:chatter_token_url    = 'https://login.salesforce.com/services/oauth2/token'
let s:chatter_auth_url     = 'https://login.salesforce.com/services/oauth2/authorize'
let s:chatter_redirect_url = 'https://login.salesforce.com/services/oauth2/success'
let s:chatter_services     = '/services/data'
let s:chatter_version      = '/services/data/v25.0'
let s:chatter_users_me     = '/chatter/users/me'
let s:chatter_feeditems    = '/chatter/feed-items'
let s:chatter_comments_likes = '/chatter/comments'
let s:chatter_comments     = '/comments'
let s:chatter_likes        = '/likes'
let s:chatter_feeds_to_me_feeds_items   = '/chatter/feeds/to/me/feed-items'
let s:chatter_feeds_news_me_feeds_items = '/chatter/feeds/news/me/feed-items'
let s:chatter_feeds_company_feeds_items = '/chatter/feeds/company/feed-items'

let s:error_code_ok =  0
let s:error_code_ng = -1

let s:dic_name_id = {}

let s:list_linenum_to_id_for_comments     = []
let s:list_linenum_to_id_for_delete_likes = []
let s:list_linenum_to_id_for_post_likes   = []

let s:URLMATCH = '\%([Hh][Tt][Tt][Pp]\|[Hh][Tt][Tt][Pp][Ss]\|[Ff][Tt][Pp]\)://\S\+'

" -------------------------------
" functions for debug
" -------------------------------
function! s:debug_echo(msg)
    if s:flag_debug_echo == 1
        echo a:msg
    endif
endfunction

function! s:debug_echo_curl_cmd(msg)
    if s:flag_debug_echo_curl_cmd == 1
        echo a:msg
    endif
endfunction

function! s:debug_echo_result(msg)
    if s:flag_debug_echo_result == 1
        echo a:msg
    endif
endfunction

function! s:debug_write_result_to_file(result)
    if s:flag_debug_prettyprint == 1
        let l:filename = s:debug_prettyprint_filesname . localtime() . '.txt'

        let l:output = split(a:result, '\n\|\r')
        if writefile(l:output, l:filename) < 0
            call s:errormsg('Error writing result file: ' . v:errmsg)
            return
        endif
    endif
endfunction

" -------------------------------
" private functions
" -------------------------------
function! s:error_msg(msg)
    echohl WarningMsg
    echomsg '[ERROR] ' . a:msg . '!'
    echohl None
endfunction

function! s:launch_browser(url)
    let startcmd = has("win32") || has("win64") ? "!start " : "! "
    let endcmd = has('unix') ? '> /dev/null &' : ''

    if has('unix') || !exists('g:chatter_browser_cmd') || g:chatter_browser_cmd == ''
        echo a:url
        echo '1. access avobe URL in you browser.'
        echo '2. login to a chatter site and allow ChatterVim to access chatter.'
        echo '3. after allowing, copy a redirected URL from an address bar of your browser and paste here.'
        return
    endif

    echo 'Launching web browser...'

    let v:errmsg = ''
    let l:url = substitute(a:url, '!\|#\|%', '\\&', 'g')
    silent! execute startcmd g:chatter_browser_cmd l:url endcmd
    if v:errmsg == ''
        echo '1. Web browser launched.'
        echo '2. login to a chatter site and allow ChatterVim to access chatter.'
        echo '3. after allowing, copy a redirected URL from an address bar of your browser and paste here.'
    else
        call s:errormsg('Error launching browser: ' . v:errmsg)
        return
    endif

    return
endfunction

function! s:write_tokens()
    let l:tokenfile = s:get_chatter_token_file()

    let l:lines = []
    call add(l:lines, g:chatter_access_token)
    call add(l:lines, g:chatter_refresh_token)
    call add(l:lines, g:chatter_instance_url)

    try
        if writefile(l:lines, l:tokenfile) < 0
            call s:errormsg('Error writing token file: ' . v:errmsg)
            return
        endif
    catch
        call s:errormsg('Error writing token file: ' . v:errmsg)
        return
    endtry

"    if has('unix')
"        let l:perms = getfperm(l:tokenfile)
"        if l:perms != '' && l:perms[-6:] != '------'
"            silent! execute "!chmod go-rwx '" . l:tokenfile . "'"
"        endif
"    endif

    call ChatterVim#ChatterGetVersion()
endfunction

function! s:read_tokens()
    let l:tokenfile = s:get_chatter_token_file()
    if filereadable(l:tokenfile)
        try
            let [l:access_token, l:refresh_token, l:instance_url] = readfile(l:tokenfile, 't', 512)
        catch
            call s:errormsg('Error reading token file: ' . v:errmsg)
            return
        endtry

        if l:access_token != ''
            call s:set_chatter_access_token(l:access_token)
        endif
        if l:refresh_token != ''
            call s:set_chatter_refresh_token(l:refresh_token)
        endif
        if l:instance_url != ''
            call s:set_chatter_instance_url(l:instance_url)
        endif
    endif

    if s:get_chatter_refresh_token() != ''
        call ChatterVim#ChatterGetVersion()
    endif
endfunction

function! s:is_session_expired(msg)
    if type(a:msg) == type([])
        for l:err in a:msg
            if type(l:err) == type({}) && has_key(l:err, 'errorCode')
                if l:err.errorCode == 'INVALID_SESSION_ID'
                    return 1
                endif
            endif
        endfor
    endif

    return 0
endfunction

function! s:parse_json(str)
    if a:str == ''
        return {}
    endif

    try
        let true = 1
        let false = 0
        let null = ''
        sandbox let result = eval(a:str)
        return result
    catch
        call s:error_msg('JSON parse error: ' . v:exception)
        return {}
    endtry
endfunction

function! s:get_curl_cmd()
    if s:get_chatter_access_token() == ''
        call s:read_tokens()
        if s:get_chatter_access_token() == ''
            call s:GetAccessToken()
        endif
    endif

    let l:curl_cmd = 'curl -k --silent '
    if s:flag_debug_prettyprint == 1
        let l:curl_cmd .= '-H X-PrettyPrint:1 '
    endif
    if s:get_chatter_proxy() != ''
        let l:curl_cmd .= "-x '" . s:get_chatter_proxy() . "' "
    endif

    return l:curl_cmd
endfunction

function! s:call_curl_and_get_result_in_json(func_name, ...)
    let l:curl_cmd = ''
    if len(a:000)
        let l:curl_cmd = function(a:func_name)(a:000)
    else
        let l:curl_cmd = function(a:func_name)()
    endif
    let l:result = system(l:curl_cmd)
    call s:debug_write_result_to_file(l:result)
    let l:result_json = s:parse_json(l:result)
    call s:debug_echo_result(l:result_json)

    return l:result_json
endfunction

"    'items
"    []
"    'actor'
"    'name'
function! s:get_name_from_json(msg)
    if has_key(a:msg, 'actor')
        let l:actor = a:msg['actor']
        if has_key(l:actor, 'name')
            let l:name = l:actor['name']
            call extend(s:dic_name_id, { l:name : l:actor['id'] })
            return l:name
        endif
    endif

    return ''
endfunction

"    'items
"    []
"    'user'
"    'name'
function! s:get_user_name_from_json(msg)
    if has_key(a:msg, 'user')
        let l:user= a:msg['user']
        if has_key(l:user, 'name')
            let l:name = l:user['name']
            call extend(s:dic_name_id, { l:name : l:user['id'] })
            return l:name
        endif
    endif

    return ''
endfunction

"    'items'
"    []
"    'body'
"    'text'
function! s:get_text_from_json(msg)
    if has_key(a:msg, 'body')
        let l:body = a:msg['body']
        if has_key(l:body, 'text')
            let l:text = l:body['text']
            return l:text
        endif
    endif

    return ''
endfunction

"    'items'
"    []
"    'modifiedDate'
function! s:get_time_from_json(msg)
    if has_key(a:msg, 'createdDate')
        let l:cdate = a:msg['createdDate']
        let l:date  = matchstr(l:cdate, '\d\d\d\d-\d\d-\d\d')
        let l:time  = matchstr(l:cdate, '\d\d:\d\d\:\d\d')
        return l:date . ' ' . l:time
    endif

    return ''
endfunction

"    'items'
"    []
"    'comments'
"    'total'
function! s:get_comments_num_from_json(msg)
    if has_key(a:msg, 'comments')
        let l:comments = a:msg['comments']
        if has_key(l:comments, 'total')
            let l:total= l:comments['total']
            return l:total
        endif
    endif

    return ''
endfunction

"    'items'
"    []
"    'likes'
"    'total'
function! s:get_likes_from_json(msg)
    if has_key(a:msg, 'likes')
        let l:likes = a:msg['likes']
        if has_key(l:likes, 'total')
            let l:total= l:likes['total']
            return l:total
        endif
    endif

    return ''
endfunction

"    'items'
"    []
"    'likes'
"    'likes'
"    []
"    'id'
function! s:get_likes_id_from_json(msg)
    if has_key(a:msg, 'likes')
        let l:likes = a:msg['likes']
        if has_key(l:likes, 'likes')
            let l:likes_contents = l:likes['likes']
            for l:contents in l:likes_contents
                if has_key(l:contents, 'id')
                    let l:id = l:contents['id']
                    return l:id
                endif
            endfor
        endif
    endif

    return ''
endfunction

"    'items'
"    []
"    'likes'
"    'currentPageUrl'
function! s:get_likes_url(msg)
    if has_key(a:msg, 'likes')
        let l:likes = a:msg['likes']
        if has_key(l:likes, 'currentPageUrl')
            let l:url = l:likes['currentPageUrl']
        endif
    endif

    if l:url == ''
        let l:id = s:get_feed_id_from_json(a:msg)
        if l:id != ''
            return s:chatter_version . s:chatter_feeditems . '/' . l:id . '/likes'
        endif
    else
        return l:url
    endif

    return ''
endfunction

function! s:get_likes_url_for_comments(msg)
    let l:url = ''
    if has_key(a:msg, 'likes')
        let l:likes = a:msg['likes']
        if has_key(l:likes, 'currentPageUrl')
            let l:url = l:likes['currentPageUrl']
        endif
    endif

    if l:url == ''
        let l:id = s:get_feed_id_from_json(a:msg)
        if l:id != ''
            return s:chatter_version . '/chatter/comments/' . l:id . '/likes'
        endif
    else
        return l:url
    endif

    return ''
endfunction

"    'items'
"    []
"    'id'
function! s:get_feed_id_from_json(msg)
    if has_key(a:msg, 'id')
        let l:id = a:msg['id']
        return l:id
    endif

    return ''
endfunction

function! s:get_comments(output_json)
    let l:time_line = []

    if has_key(a:output_json, 'comments')
        for l:comments in a:output_json['comments']
            let l:name  = s:get_user_name_from_json(l:comments)
            let l:text  = s:get_text_from_json(l:comments)
            let l:likes = s:get_likes_from_json(l:comments)
            let l:time  = s:get_time_from_json(l:comments)
            let l:id    = s:get_feed_id_from_json(l:comments)
            let l:likes_id = s:get_likes_id_from_json(l:comments)
            let l:likes_url = s:get_likes_url_for_comments(l:comments)

            let l:line  = l:name . ': '
            let l:line .= l:text . ' '
            if s:get_chatter_show_likes_in_timeline() == 1
                let l:line .= '[likes: ' . l:likes . '] '
            endif
            let l:line .= ' |' . l:time . '|'
            let l:msg = split(l:line, '\n\|\r')
            for l:split in l:msg
                call add(s:list_linenum_to_id_for_post_likes, l:likes_url)
                call add(s:list_linenum_to_id_for_delete_likes, l:likes_id)
                call add(l:time_line, repeat(' ', 2) . '| ' . l:split)
            endfor

            call add(s:list_linenum_to_id_for_post_likes, l:likes_url)
            call add(s:list_linenum_to_id_for_delete_likes, l:likes_id)
            call add(l:time_line, repeat(' ', 2) . repeat('-', 78))
        endfor
    endif

    return l:time_line
endfunction

function! s:print_feed_items(output_json)
    let l:time_line = []
    let s:dic_name_id = {}

    " set buffer title
    let l:buf_title = 'Chatter Timeline'
    call add(l:time_line, repeat('=', strlen(l:buf_title)) . '*')
    call add(l:time_line, l:buf_title . '*')
    call add(l:time_line, repeat('=', strlen(l:buf_title)) . '*')

    let s:list_linenum_to_id_for_comments     = ['', '', '']
    let s:list_linenum_to_id_for_delete_likes = ['', '', '']
    let s:list_linenum_to_id_for_post_likes   = ['', '', '']

    " set timeline
    let l:timeline_count = 0
    if has_key(a:output_json, 'items')
        for l:items in a:output_json['items']
            " set lines
            let l:name  = s:get_name_from_json(l:items)
            let l:text  = s:get_text_from_json(l:items)
            let l:comments_num = s:get_comments_num_from_json(l:items)
            let l:likes = s:get_likes_from_json(l:items)
            let l:time  = s:get_time_from_json(l:items)
            let l:id    = s:get_feed_id_from_json(l:items)
            let l:likes_id = s:get_likes_id_from_json(l:items)
            let l:likes_url = s:get_likes_url(l:items)

            let l:line  = l:name . ': '
            let l:line .= l:text . ' '
            if s:get_chatter_show_comments_num_in_timeline() == 1
                let l:line .= '[comments: ' . l:comments_num . ']'
            endif
            if s:get_chatter_show_likes_in_timeline() == 1
                let l:line .= '[likes: ' . l:likes . '] '
            endif
            let l:line .= ' |' . l:time . '|'

            " split at \n
            let l:msg = split(l:line, '\n\|\r')
            for l:split in l:msg
                call add(s:list_linenum_to_id_for_post_likes, l:likes_url)
                call add(s:list_linenum_to_id_for_delete_likes, l:likes_id)
                call add(s:list_linenum_to_id_for_comments, l:id)
                call add(l:time_line, l:split)
            endfor

            " added comments
            if l:comments_num != 0
                if has_key(l:items, 'comments')
                    let l:comments = s:get_comments(l:items['comments'])
                    let i = 0
                    while i < len(l:comments)
                        call add(s:list_linenum_to_id_for_comments, l:id)
                        let i = i + 1
                    endwhile
                    call extend(l:time_line, l:comments)
                endif
            endif

            " count timeline num
            let l:timeline_count = l:timeline_count + 1
            if l:timeline_count >= s:get_chatter_show_timeline_num()
                break
            endif
        endfor
    endif

    call s:chatter_wintext(l:time_line)
endfunction

function! s:chatter_win_keymap()
    nnoremap <buffer> <silent> q :bd<CR>
    nnoremap <buffer> <silent> <Leader>c :call ChatterVim#ChatterPostComments()<CR>
    nnoremap <buffer> <silent> <Leader>u :call ChatterVim#ChatterGetFeedsUserProfileFeedItems()<CR>
    nnoremap <buffer> <silent> <Leader>l :call ChatterVim#ChatterPostLikes()<CR>
    nnoremap <buffer> <silent> <Leader>L :call ChatterVim#ChatterDeleteLikes()<CR>
endfunction

function! s:chatter_win_syntax()
    if has("syntax") && exists("g:syntax_on")
        syntax clear

        " avoid colon in like/comments braces
        syntax match chatterUser /\(^\|\s\s|\s\)[^[]\+:\ / contains=chatterIndent
        syntax match chatterIndent /\s\s|\s/ contained

        syntax match chatterTime /|[^|]\+|$/ contains=chatterTimeBar
        syntax match chatterTimeBar /|/ contained

        execute 'syntax match chatterLink "\<' . s:URLMATCH . '"'

        syntax match chatterReply "\w\@<!@\w\+"

        syntax match chatterLink "\w\@<!#\w\+"
        syntax match chatterLike "\[likes: \d\+\]"

        syntax match chatterTitle /^\%(\w\+:\)\@!.\+\*$/ contains=chatterTitleStar
        syntax match chatterTitleStar /\*$/ contained

        highlight default link chatterUser Identifier
        highlight default link chatterIndent Normal
        highlight default link chatterTime String
        highlight default link chatterTimeBar Normal
        highlight default link chatterTitle Title
        highlight default link chatterTitleStar Normal
        highlight default link chatterLink Underlined
        highlight default link chatterLike Label
        highlight default link chatterReply Label
    endif
endfunction

function! s:create_chatter_win()
    let winname = 'ChatterFeeds' " . localtime()
    let newwin = 0

    let chatter_bufnr = bufwinnr('^' . winname . '$')
    if chatter_bufnr > 0
        execute chatter_bufnr . "wincmd w"
    else
        let newwin = 1
        execute "new " . winname
        setlocal noswapfile
        setlocal buftype=nofile
        setlocal bufhidden=delete
        setlocal foldcolumn=0
        setlocal nobuflisted
        setlocal nospell
    endif

    call s:chatter_win_keymap()

    setlocal filetype=chattervim
    call s:chatter_win_syntax()
    return newwin
endfunction

function! s:chatter_wintext(msg)
    let curwin = winnr()
    let newwin = s:create_chatter_win()

    setlocal modifiable

    silent %delete _

    call setline('.', a:msg)

    normal! 1G

    setlocal nomodifiable

    if newwin
        wincmd p
    else
        execute curwin .  "wincmd w"
    endif
endfunction

function! s:get_access_token_from_url(url)
    let l:urls = split(a:url, "#")
    call remove(l:urls, 0)

    let l:urls = split(l:urls[0], "&")
    for l:url in l:urls
        if match(l:url, "^access_token=") != -1
            let l:length = strlen("access_token=")
            return l:url[l:length :]
        endif
    endfor
endfunction

function! s:get_refresh_token_from_url(url)
    let l:urls = split(a:url, "#")
    call remove(l:urls, 0)

    let l:urls = split(l:urls[0], "&")
    for l:url in l:urls
        if match(l:url, "^refresh_token=") != -1
            let l:length = strlen("refresh_token=")
            return l:url[l:length :]
        endif
    endfor
endfunction

function! s:get_instance_url_from_url(url)
    let l:urls = split(a:url, "#")
    call remove(l:urls, 0)

    let l:urls = split(l:urls[0], "&")
    for l:url in l:urls
        if match(l:url, "^instance_url=") != -1
            let l:length = strlen("instance_url=")
            return l:url[l:length :]
        endif
    endfor
endfunction

function! s:GetAccessToken()
    let l:url_cmd  = s:chatter_auth_url
    let l:url_cmd .= '?response_type=token'
    let l:url_cmd .= '&client_id=' . s:get_chatter_client_id()
    let l:url_cmd .= '&redirect_uri=' . s:chatter_redirect_url

    call s:debug_echo(l:url_cmd)
    call s:launch_browser(l:url_cmd)

    let l:access_token = input('Input URL after allowing or access_token: ')
    if len(l:access_token) == 0
        call s:error_msg('canceled input access_token')
        return s:error_code_ng
    endif

    if match(l:access_token, '^http') != -1
        let l:refresh_token = s:get_refresh_token_from_url(l:access_token)
        let l:instance_url  = s:get_instance_url_from_url(l:access_token)
        let l:access_token  = s:get_access_token_from_url(l:access_token)
    else
        let l:refresh_token= input('Input refresh_token: ')
        if len(l:refresh_token) == 0
            call s:error_msg('canceled input refresh_token')
            return s:error_code_ng
        endif
        let l:instance_url= input('Input instance_url: ')
        if len(l:instance_url) == 0
            call s:error_msg('canceled input instance_url')
            return s:error_code_ng
        endif
    endif

    let l:access_token  = s:url_decode(l:access_token)
    let l:refresh_token = s:url_decode(l:refresh_token)
    let l:instance_url  = s:url_decode(l:instance_url)

    call s:set_chatter_access_token(l:access_token)
    call s:set_chatter_refresh_token(l:refresh_token)
    call s:set_chatter_instance_url(l:instance_url)

    call s:write_tokens()
    redraw
    echo '[OK] get access_token successfully.'

    return s:error_code_ok
endfunction

function! s:create_curl_cmd_for_get_access_token_by_refresh_token()
    let l:curl_cmd  = 'curl -k --silent '
    if len(s:get_chatter_proxy()) != 0
        let l:curl_cmd .= '-x "' . s:get_chatter_proxy() . '" '
    endif
    let l:curl_cmd .= '-X POST '
    let l:curl_cmd .= s:chatter_token_url . ' '
    let l:curl_cmd .= '--form grant_type=refresh_token '
    let l:curl_cmd .= '--form client_id=' . s:get_chatter_client_id() . ' '
    let l:curl_cmd .= '--form refresh_token=' . s:get_chatter_refresh_token()
    call s:debug_echo_curl_cmd(l:curl_cmd)
    return l:curl_cmd
endfunction

function! s:GetAccessToken_by_refresh_token()
    if s:get_chatter_refresh_token() == ''
        call s:GetAccessToken()
        return
    endif

    let l:output_json = s:call_curl_and_get_result_in_json('s:create_curl_cmd_for_get_access_token_by_refresh_token')
    if !has_key(l:output_json, 'access_token')
        call s:error_msg('cannot parse access_token from JSON')
        return s:error_code_ng
    endif

    if l:output_json.access_token == ''
        call s:error_msg('access_token is empty')
        return s:error_code_ng
    endif
    call s:set_chatter_access_token(l:output_json.access_token)

    if l:output_json.instance_url == ''
        call s:error_msg('instance url is empty')
        return s:error_code_ng
    endif
    call s:set_chatter_instance_url(l:output_json.instance_url)

    call s:write_tokens()
    echo '[OK] refresh access_token successfully.'

    return s:error_code_ok
endfunction

function! s:url_encode_char(c)
    let utf = iconv(a:c, &encoding, "utf-8")
    if utf == ""
        let utf = a:c
    endif

    let s = ""
    for i in range(strlen(utf))
        let s .= printf("%%%02X", char2nr(utf[i]))
    endfor

    return s
endfunction

function! s:url_encode(str)
    return substitute(a:str, '[^a-zA-Z0-9_.~-]', '\=s:url_encode_char(submatch(0))', 'g')
endfunction

function! s:url_decode(str)
    return substitute(a:str, '%\(\x\x\)', '\=printf("%c", str2nr(submatch(1), 16))', 'g')
endfunction

function! s:get_username(line)
    let l:line = substitute(a:line, '^\ \+|\ \+', '', '')
    let l:name = split(l:line, ':')
    return l:name != [] ? l:name[0] : ""
endfunction

function! s:create_curl_cmd_for_post_likes(args)
    let l:args = a:args[0]
    let l:access_id = l:args[0]
    let l:curl_cmd  = s:get_curl_cmd()
    let l:curl_cmd .= '-X POST '
    let l:curl_cmd .= s:get_chatter_instance_url()
    let l:curl_cmd .= l:args[0] . ' '
    let l:curl_cmd .= "-H 'Authorization: OAuth " . s:get_chatter_access_token() . "' "
    call s:debug_echo_curl_cmd(l:curl_cmd)
    return l:curl_cmd
endfunction

function! s:create_curl_cmd_for_delete_likes(args)
    let l:args = a:args[0]
    let l:access_id = l:args[0]
    let l:curl_cmd  = s:get_curl_cmd()
    let l:curl_cmd .= '-X DELETE '
    let l:curl_cmd .= s:get_chatter_instance_url()
    let l:curl_cmd .= s:chatter_version
    let l:curl_cmd .= '/chatter/likes/' . l:access_id . ' '
    let l:curl_cmd .= "-H 'Authorization: OAuth " . s:get_chatter_access_token() . "' "
    call s:debug_echo_curl_cmd(l:curl_cmd)
    return l:curl_cmd
endfunction

function! s:create_curl_cmd_for_post_comments(args)
    let l:args = a:args[0]
    let l:access_id = l:args[0]
    let l:text      = l:args[1]
    let l:curl_cmd  = s:get_curl_cmd()
    let l:curl_cmd .= '-X POST '
    let l:curl_cmd .= s:get_chatter_instance_url()
    let l:curl_cmd .= s:chatter_version
    let l:curl_cmd .= s:chatter_feeditems . '/' . l:access_id . s:chatter_comments
    let l:curl_cmd .= '?text=' . l:text . ' '
    let l:curl_cmd .= "-H 'Authorization: OAuth " . s:get_chatter_access_token() . "' "
    call s:debug_echo_curl_cmd(l:curl_cmd)
    return l:curl_cmd
endfunction

function! s:create_curl_cmd_for_get_feeds_user_profile_feed_items(args)
    let l:args = a:args[0]
    let l:access_id = l:args[0]
    let l:curl_cmd  = s:get_curl_cmd()
    let l:curl_cmd .= '-X GET '
    let l:curl_cmd .= s:get_chatter_instance_url()
    let l:curl_cmd .= s:chatter_version
    let l:curl_cmd .= '/chatter/feeds/user-profile/' . l:access_id . '/feed-items '
    let l:curl_cmd .= "-H 'Authorization: OAuth " . s:get_chatter_access_token() . "' "
    call s:debug_echo_curl_cmd(l:curl_cmd)
    return l:curl_cmd
endfunction

function! s:create_curl_cmd_for_post_feeds_news_me_feed_items(args)
    let l:args = a:args[0]
    let l:text = l:args[0]
    let l:curl_cmd  = s:get_curl_cmd()
    let l:curl_cmd .= '-X POST '
    let l:curl_cmd .= s:get_chatter_instance_url()
    let l:curl_cmd .= s:chatter_version
    let l:curl_cmd .= s:chatter_feeds_news_me_feeds_items
    let l:curl_cmd .= '?text=' . l:text . ' '
    let l:curl_cmd .= "-H 'Authorization: OAuth " . s:get_chatter_access_token() . "' "
    call s:debug_echo_curl_cmd(l:curl_cmd)
    return l:curl_cmd
endfunction

function! s:create_curl_cmd_for_get_feeds_news_me_feed_items()
    let l:curl_cmd  = s:get_curl_cmd()
    let l:curl_cmd .= '-X GET '
    let l:curl_cmd .= s:get_chatter_instance_url()
    let l:curl_cmd .= s:chatter_version
    let l:curl_cmd .= s:chatter_feeds_news_me_feeds_items . ' '
    let l:curl_cmd .= "-H 'Authorization: OAuth " . s:get_chatter_access_token() . "' "
    call s:debug_echo_curl_cmd(l:curl_cmd)
    return l:curl_cmd
endfunction

function! s:create_curl_cmd_for_get_feeds_company_feed_items()
    let l:curl_cmd  = s:get_curl_cmd()
    let l:curl_cmd .= '-X GET '
    let l:curl_cmd .= s:get_chatter_instance_url()
    let l:curl_cmd .= s:chatter_version
    let l:curl_cmd .= s:chatter_feeds_company_feeds_items . ' '
    let l:curl_cmd .= "-H 'Authorization: OAuth " . s:get_chatter_access_token() . "' "
    call s:debug_echo_curl_cmd(l:curl_cmd)
    return l:curl_cmd
endfunction

function! s:create_curl_cmd_for_get_feeds_to_me_feed_items()
    let l:curl_cmd  = s:get_curl_cmd()
    let l:curl_cmd .= '-X GET '
    let l:curl_cmd .= s:get_chatter_instance_url()
    let l:curl_cmd .= s:chatter_version
    let l:curl_cmd .= s:chatter_feeds_to_me_feeds_items . ' '
    let l:curl_cmd .= "-H 'Authorization: OAuth " . s:get_chatter_access_token() . "' "
    call s:debug_echo_curl_cmd(l:curl_cmd)
    return l:curl_cmd
endfunction

function! s:create_curl_cmd_for_get_version()
    let l:curl_cmd  = s:get_curl_cmd()
    let l:curl_cmd .= s:get_chatter_instance_url()
    let l:curl_cmd .= s:chatter_services
    call s:debug_echo_curl_cmd(l:curl_cmd)
    return l:curl_cmd
endfunction

function! s:exec_curl(func_name, ...)
    if len(a:000)
        let l:output_json = s:call_curl_and_get_result_in_json(a:func_name, a:000)
    else
        let l:output_json = s:call_curl_and_get_result_in_json(a:func_name)
    endif

    if s:is_session_expired(l:output_json) == 1
        let l:reuslt = s:GetAccessToken_by_refresh_token()
        if l:reuslt != s:error_code_ok
            call s:error_msg('failed to refresh access_token')
            return {}
        endif

        if len(a:000)
            let l:output_json2 = s:call_curl_and_get_result_in_json(a:func_name, a:000)
        else
            let l:output_json2 = s:call_curl_and_get_result_in_json(a:func_name)
        endif
        if s:is_session_expired(l:output_json2) == 1
            call s:error_msg("refreshed access_token but it's expired yet")
            return {}
        endif

        if has_key(l:output_json2, 'errorCode')
            call s:error_msg('errorCode was found in result JSON')
            return {}
        endif

        return l:output_json2
    endif

    if has_key(l:output_json, 'errorCode')
        call s:error_msg('errorCode was found in result JSON')
        return {}
    endif

    return l:output_json
endfunction

" ------------------------------------
" functions for calling from public
" ------------------------------------
function! ChatterVim#ChatterPostLikes()
    let l:linenum = line(".") - 1
    let l:access_id = ''
    if l:linenum < len(s:list_linenum_to_id_for_post_likes)
        let l:access_id = s:list_linenum_to_id_for_post_likes[l:linenum]
    endif

    if l:access_id == ''
        return
    endif

    call inputsave()
    redraw
    let l:text = input('Post likes? y/n: ')
    call inputrestore()
    if l:text[0] != 'y' && l:text[0] != 'Y'
        echo 'ChatterPostLikes was canceled.'
        return
    endif

    let l:result = s:exec_curl('s:create_curl_cmd_for_post_likes', l:access_id)
    if l:result != {}
        echo 'ChatterPostLikes was succeed.'
    endif
endfunction

function! ChatterVim#ChatterDeleteLikes()
    let l:linenum = line(".") - 1
    let l:access_id = ''
    if l:linenum < len(s:list_linenum_to_id_for_delete_likes)
        let l:access_id = s:list_linenum_to_id_for_delete_likes[l:linenum]
    endif

    if l:access_id == ''
        return
    endif

    call inputsave()
    redraw
    let l:text = input('Delete likes? y/n: ')
    call inputrestore()
    if l:text[0] != 'y' && l:text[0] != 'Y'
        echo 'ChatterDeleteLikes was canceled.'
        return
    endif

    let l:result = s:exec_curl('s:create_curl_cmd_for_delete_likes', l:access_id)
    if l:result != {}
        echo 'ChatterDeleteLikes was succeed.'
    endif
endfunction

function! ChatterVim#ChatterPostComments()
    let l:linenum = line(".") - 1
    let l:access_id = ''
    if l:linenum < len(s:list_linenum_to_id_for_comments)
        let l:access_id = s:list_linenum_to_id_for_comments[l:linenum]
    endif

    if l:access_id == ''
        return
    endif

    call inputsave()
    redraw
    let l:text = input('Input Your Comments: ')
    call inputrestore()
    if len(l:text) == 0
        echo 'ChatterPostComments was canceled.'
        return
    endif
    let l:text = s:url_encode(l:text)

    let l:result = s:exec_curl('s:create_curl_cmd_for_post_comments', l:access_id, l:text)
    if l:result != {}
        echo 'ChatterPostComments was succeed.'
    endif
endfunction

function! ChatterVim#ChatterGetFeedsUserProfileFeedItems()
    let l:username = s:get_username(getline('.'))
    if l:username == ''
        return
    endif

    let l:access_id = ''
    for [l:name, l:id] in items(s:dic_name_id)
        if l:username == l:name
            let l:access_id = l:id
            break
        endif
    endfor
    if l:access_id == ''
        return
    endif

    let l:result = s:exec_curl('s:create_curl_cmd_for_get_feeds_user_profile_feed_items', l:access_id)
    call s:print_feed_items(l:result)
endfunction

function! ChatterVim#ChatterPostFeedsNewsMeFeedItems()
    call inputsave()
    redraw
    let l:text = input('Input Your Message: ')
    call inputrestore()
    if len(l:text) == 0
        echo 'ChatterPost was canceled.'
        return
    endif
    let l:text = s:url_encode(l:text)

    let l:result = s:exec_curl('s:create_curl_cmd_for_post_feeds_news_me_feed_items', l:text)
    if l:result != {}
        echo 'ChatterPost was succeed.'
    endif
endfunction

function! ChatterVim#ChatterGetFeedsNewsMeFeedItems()
    let l:result = s:exec_curl('s:create_curl_cmd_for_get_feeds_news_me_feed_items')
    call s:print_feed_items(l:result)
endfunction

function! ChatterVim#ChatterGetFeedsToMeFeedItems()
    let l:result = s:exec_curl('s:create_curl_cmd_for_get_feeds_to_me_feed_items')
    call s:print_feed_items(l:result)
endfunction

function! ChatterVim#ChatterGetFeedsCompanyFeedItems()
    let l:result = s:exec_curl('s:create_curl_cmd_for_get_feeds_company_feed_items')
    call s:print_feed_items(l:result)
endfunction

function! ChatterVim#ChatterGetVersion()
    let l:output_json = s:call_curl_and_get_result_in_json('s:create_curl_cmd_for_get_version')
    if len(l:output_json) == 0
        call s:error_msg('failed to parse JSON')
        return
    endif

    let l:latest_ver = 0.0
    for l:ver in l:output_json
        if !has_key(l:ver, 'version')
            call s:error_msg('there is no version info')
            return
        endif

        if v:version <= 701
            let l:current_ver = l:ver.version
        else
            let l:current_ver = str2float(l:ver.version)
        endif
        if l:latest_ver < l:current_ver
            let l:latest_ver = l:current_ver
            let l:latest_url = l:ver.url
        endif
    endfor

    if l:latest_ver == 0.0
        call s:error_msg('failed to get a version')
        return
    endif

    let s:chatter_version = l:latest_url
endfunction

let &cpo = s:save_cpo
finish

