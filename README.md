# asterisk-minitel-docker

> Docker image for Asterisk with Minitel server

See https://vectronic.io/posts/minitel-terminal-connected-via-asterisk/

### Build

`docker build -t vectronic/asterisk-minitel .`

### Configuration

Modify the files:

`config/extensions.conf.sample`
`config/pjsip.conf.sample`

as appropriate and then rename to:

`config/extensions.conf`
`config/pjsip.conf`

### Usage

`docker run -d -v ./config:/etc/asterisk --network host vectronic/asterisk-minitel`
