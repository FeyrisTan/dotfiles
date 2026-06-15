function rplasma --description 'Restart plasmashell (Plasma 6)'
    setsid -f plasmashell --replace >/dev/null 2>&1
end
