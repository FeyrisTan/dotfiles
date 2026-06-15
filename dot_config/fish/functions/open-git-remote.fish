function open-git-remote
    set url (git remote get-url origin)
    
    # Convert SSH to HTTPS if necessary
    if string match -q "git@*" $url
        set url (string replace -r '^git@([^:]+):' 'https://$1/' $url)
    end
    
    # Strip .git suffix
    set url (string replace -r '\.git$' '' $url)
    
    # Open in default browser (Linux only)
    xdg-open $url
end
