@rem Copyright (c) Huawei Technologies Co., Ltd. 2020-2030. All rights reserved.
@ECHO OFF

SETLOCAL

SET "CUR_DIR=%~dp0"

SET NPM_CMD="%NODE_HOME%\npm.cmd"
IF NOT EXIST %NPM_CMD% (
  SET NPM_CMD=npm
)

CALL %NPM_CMD% -v  >nul 2>nul

IF %errorlevel% NEQ 0 (
  echo [31mERROR: 'node' command not found.[0m
  exit /b 1
)
