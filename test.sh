#!/bin/sh

export MIX_ENV=test
mix ecto.reset && mix test
