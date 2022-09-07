serverConfig = {
    use_steam = true,
    only_priority = false,
    connect_timeout_length = 600,
    queue_timeout_length = 90,
    use_grace_system = false,
    default_grace_level = 5,
    grace_ability_length = 480,
    queue_join_delay = 4500,
    show_queue_temp = false,
    disable_hardcap = true,
    translate = {
        title = "\xF0\x9F\x8E\x89Connectin",
        joining = "\xF0\x9F\x8E\x89Joining to server",                                                                                  --// lang when player joining to server //--
        connecting = "\xE2\x8F\xB3Connecting to server",                                                                                   --// lang when player connecting to server //--
        id_error = "\xE2\x9D\x97 System Error : your server id's not found, try to restart your FiveM (ERROR 001)",                      --// lang when player ids not found //--
        error = "\xE2\x9D\x97 System Error : somethings error in our server, please wait (ERROR 002)",                                --// lang when server have error //--
        pos = "\xF0\x9F\x90\x8C You are at %d/%d in queue for \xF0\x9F\x95\x9C%s | Discord : https://discord.gg/FMWd4sk8W4",        --// lang when player queue //--
        connecting_error = "\xE2\x9D\x97 System Error : system can't adding you into the queue (ERROR 003)",                                     --// lang when server can't add player into the queue //--
        timedout  = "\xE2\x9D\x97 System Error : server timeout, contact admin for help (ERROR 004)",                                     --// lang when server timeout //--
        wlonly = "\xE2\x9D\x97 System Error : server maintenance for updating server | https://discord.gg/FMWd4sk8W4 (ERROR 005)",     --// lang when server only for priority //--
        steam = "\xE2\x9D\x97 System Error : system can't find your steam, please login steam first (ERROR 006)"                      --// lang when player not login steam //--
    },
    anti_spam = {
        enable = true,
        timer = 5,
        please_wait = function(time)
            return "Please wait ".. time .." seconds. The connection will start automatically!"
        end
    },
    custom = {
        greeting = true,
        greeting_interval = 1500,
        greeting_word = "Hai %s",

        account = true,
        account_interval = 2500,
        account_word = "Hello %s, we are checking your profile account",

        discord_not_found = "Discord account not found, please check it again",
        steam_not_found = "Steam account not found, please check it again",
        license_not_found = "Rockstar account not found, please check it again",

        banned = true,
        banned_interval = 2000,
        banned_word = "Hello %s, we are checking if you have been banned",

        not_banned_interval = 1000,

        welcome = true,
        welcome_interval = 1500,
        welcome_word = "welcome %s to NKCore"
    },
    adaptive_card = {
        background_image = "https://media.discordapp.net/attachments/866360474223640597/907577250621317150/banerULOL.png?width=1440&height=356",
        icon_center = "https://cdn.discordapp.com/attachments/996664171338944523/996664204381659156/LOL960trnspant.png",
        column = {
            button_1 = {
                title = "See our Shop",
                url = "https://benjamin4k.tebex.io/"
            },
            button_2 = {
                title = "See our Website",
                url = "https://benjamin4k.my.id"
            }
        },
        action = {
            title = "Discord server",
            url = "https://discord.gg/7rFQQ6yeW7"
        }
    },
    priority = {
        ["steam:110000142060e9c"]       = 99,   --// Nakaaa //--
    }
}