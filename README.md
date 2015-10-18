# Sake

**Sake** (Storage Abstraction Client) combines multiple storage services as a single big storage and help you upload or download your files.

Storage services supported:

*   MediaFire

## Getting Started

Configure your accounts.

    $ vim config.json
    {
        "stores": [
            {
                "location": "Mediafire",
                "accounts": [
                    {
                        "email":    "",
                        "password": "",
                        "app_id":   "99999",
                        "api_key":  "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                    },
                    ...
                ]
            }
        ]
    }

Install gems and run the CLI.

    $ bundle install
    $ bundle exec ./cli /path/to/config.json
    > help       
      Commands:
        login         : login
        ls            : ls [path]
        mkdir         : mkdir path
        rmdir         : rmdir path
        rmdir_f       : rmdir_f path
        put           : put local remote
        get           : get remote local
        rm            : rm path
        rm_f          : rm_f path
        trash_rm      : trash_rm path
        trash_rm_all  : trash_rm_all
        help          : help
        exit          : exit
    > login
    > ls
                - 2015-04-18T01:18:56Z test
           6.00 B 2015-04-18T01:19:14Z testfile
    > rm /testfile
    > ls
                - 2015-04-18T01:18:56Z test
