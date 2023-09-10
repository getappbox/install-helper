

## Install/Update Steps

#### Change USER

```
sudo su vapor
```

#### Change directory

```
cd install-helper
```

#### Update code

```
git fetch && git pull
```

#### Build Release App

```
swift build -c release
```

#### Restart Service

```
sudo service installhelper restart
```
