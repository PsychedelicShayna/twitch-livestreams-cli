# Twitch Livestream Checker
This is a simple Ruby script that retrieves the current livestream metadata of any given list of streamers. This script requires a Twitch API client id and secret to function, neither of which are included. You can find out how to get your own client id and secret by checking out the Twitch API docs : https://dev.twitch.tv/docs/authentication#registration

This script requires the colorize gem in order to colorize the output (mandatory).
![](screenshots/1.png?raw=true)

## Config
While command line arguments are a way to give required info, you should ideally be using the json config file. You can generate a new config file using `--new-config-file`.
```json
{
    "client_id": "",
    "client_secret": "",

    "loop_mode": true,

    "streamers": [
        "xqcow",
        "m0xyy",
        "5uppp"
    ]
}
```

## Command Line Arguments
`livestreams.rb --help`
```
--help (-h)                  |   This help message.. Shouldn't need an explanation.
--loop (-l)                  |   Don't exit, keep refreshing livestreams every 15 seconds.

--new-config-file (-ncf)     |   Generate a new configuration file template rather than loading from it
                                 ('config.json' default, use -cf to change config path)

--config-file (-cf)          |   Specifies the config file path containing default settings (default 'config.json')
                                 If -ncf is specified, this is the path that will be used for the new config.

--client-id (-cid)           |   Required argument -- your Twitch API client ID.
--client-secret (-cs)        |   Required argument -- your Twitch API client secret.

--streamers (-s)             |   A list of streamer logon names to monitor separated by semicolons ';' e.g. --streamers streamer1;streamer2;streamer3 etc..
                                 Ideally this should be stored in the config file.
```
