ChatterVim
==========

Chatter client for Vim.  

first, you need to authorize ChatterVim to access chatter resources.  
1. access an URL shown by ChatterVim.  
2. login chatter site and allow ChatterVim to access.  
3. after allowing, copy a redirected URL in address bar of you browser and paste to ChatterVim.  

----
settings:

  " set browser launch command
  let g:chatter_browser_cmd = 'cygstart firefox.exe'

  " set proxy
  let g:chatter_proxy = 'proxy_url:port'

----
commandline commands:

    :ChatterGetFeeds
    :ChatterGetFeedsToMe
    :ChatterGetFeedsCompany
    :ChatterPostFeeds

buffer commands:

    \c -> post comment to a feed under the cursor  
    \l -> post likes to a feed under the cursor  
    \L -> delete likes to a feed under the cursor  
    \u -> show a timeline of user under the cursor  
