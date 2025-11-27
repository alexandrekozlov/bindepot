#!/bin/sh

export MIX_ENV=test
mix ecto.reset && mix coveralls.multiple --type html --type cobertura
