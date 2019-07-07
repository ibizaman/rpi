#!/bin/bash

function arguments() {
    :
}

function install_remote() {
    pacman --noconfirm --needed -Sy \
           surf \

    cat <<SURF > /usr/local/bin/surf-web
#!/bin/bash

/usr/bin/surf https://xkcd.com
SURF
    # Example if wanting to switch to chromium-browser:
    # chromium-browser /path/to/your/file.html --window-size=1920,1080 --start-fullscreen --kiosk --incognito --noerrdialogs --disable-translate --no-first-run --fast --fast-start --disable-infobars --disable-features=TranslateUI --disk-cache-dir=/dev/null


    chmod a+x /usr/local/bin/surf-web

    ln -sf /usr/local/bin/surf-web /usr/local/bin/autologin-app
}

function install_local() {
    :
}
