## AppBox Install Helper
AppBox middleware service to provide direct access to dropbox file without cors headers.


## Install Steps

Follow these instruction https://docs.vapor.codes/deploy/digital-ocean/#initial-setup

```
# Clone (for new install only)
git clone https://github.com/getappbox/install-helper.git

# Change directory
cd install-helper

# Create .env file and add ReCAPTCHA secrets

# Run
swift run App serve --env production
```

## Update Steps
```
# Change user (do not run as root user)
sudo su vapor

# Change directory
cd install-helper

# Fetch latest changes
git fetch && git pull

# Build release app
swift build -c release

# Restart service
sudo service installhelper restart
```
