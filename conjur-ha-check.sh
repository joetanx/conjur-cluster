#!/bin/bash
podman exec conjur sv status conjur | grep run
exit $?