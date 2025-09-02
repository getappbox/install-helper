## AppBox Install Helper
AppBox middleware service to provide direct access to dropbox file without cors headers.


## Install Steps

Follow these instruction https://docs.vapor.codes/deploy/digital-ocean/#initial-setup

### Clone (for new install only)
```sh
git clone https://github.com/getappbox/install-helper.git
```

### Change directory
```sh
cd install-helper
```

### Run
```sh
swift run App serve --env production
```

### Create service file
```
/etc/systemd/system/installhelper.service
```


## Update Steps
### Change user (do not run as root user)
```sh
sudo su vapor
```

### Change directory
```sh
cd install-helper
```

### Fetch latest changes
```sh
git fetch && git pull
```

### Build release app
```sh
swift build -c release
```

### Restart service
```sh
sudo service installhelper restart
```
