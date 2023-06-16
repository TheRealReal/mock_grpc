# =========================================================================== #
#                                                                             #
#                       COMPILE-TIME CONFIG                                   #
#                                                                             #
# This file is the starting point of the whole website configuration. This    #
# file, along with `config/env/dev.exs`, `config/env/prod.exs` and            #
# `config/test.exs`, is evaluated DURING COMPILE TIME.                        #
#                                                                             #
# ! DO NOT CONFIGURE DEFAULT VALUES IN THIS FILE OR THEY MIGHT GO TO PROD !   #
#                                                                             #
# Only add configs here that do not require `System.get_env/2` and that are   #
# intended to have the same value for all environments.                       #
#                                                                             #
# Elixir will always deep-merge all configs, so you can add the basic config  #
# here and customize for each environment on the environment-specific files.  #
#                                                                             #
# =========================================================================== #
import Config

import_config "#{config_env()}.exs"
