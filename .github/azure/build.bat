@ECHO off
SETLOCAL

::===============================================================================
:: Copyright 2019-2023 Intel Corporation
::
:: Licensed under the Apache License, Version 2.0 (the "License");
:: you may not use this file except in compliance with the License.
:: You may obtain a copy of the License at
::
::     http://www.apache.org/licenses/LICENSE-2.0
::
:: Unless required by applicable law or agreed to in writing, software
:: distributed under the License is distributed on an "AS IS" BASIS,
:: WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
:: See the License for the specific language governing permissions and
:: limitations under the License.
::===============================================================================

:process_arguments
IF "%1" == "/THREADING" set "THREADING=%2"
IF "%1" == "/MODE" set "MODE=%2"
IF "%1" == "/VSVERSION" set "VSVERSION=%2"
IF "%1" == "/SOURCEDIR" set "SOURCEDIR=%2"
IF "%1" == "/BUILDDIR" set "BUILDDIR=%2"

SHIFT
SHIFT
IF NOT "%1" == "" GOTO process_arguments

vcpkg fetch ninja

SET "CMAKE_OPTIONS=-G Ninja -DCMAKE_BUILD_TYPE=%MODE% -DDNNL_BUILD_FOR_CI=ON -DDNNL_WERROR=ON"

SET "CPU_RUNTIME=NONE"
SET "GPU_RUNTIME=NONE"

IF "%THREADING%" == "omp" SET "CPU_RUNTIME=OMP"
IF "%THREADING%" == "tbb" SET "CPU_RUNTIME=TBB"
IF "%THREADING%" == "ocl" (
    SET "CPU_RUNTIME=OMP"
    SET "GPU_RUNTIME=OCL"
)

SET "CMAKE_OPTIONS=%CMAKE_OPTIONS% -DDNNL_CPU_RUNTIME=%CPU_RUNTIME% -DDNNL_GPU_RUNTIME=%GPU_RUNTIME% -DDNNL_TEST_SET=SMOKE"

CD /D %SOURCEDIR%

SET "CMAKE_OPTIONS=-B%BUILDDIR% %CMAKE_OPTIONS%"
ECHO "CMAKE OPTS: %CMAKE_OPTIONS%"

cmake ./CMakeLists.txt %CMAKE_OPTIONS%
SET err=%ERRORLEVEL%
if NOT %err% == 0 (
    if exist "%BUILDDIR%\CMakeFiles\CMakeOutput.log" (
        ECHO "CMakeOutput.log:"
        TYPE %BUILDDIR%\CMakeFiles\CMakeOutput.log
    )
    if exist "%BUILDDIR%\CMakeFiles\CMakeError.log" (
        ECHO "CMakeError.log:"
        TYPE %BUILDDIR%\CMakeFiles\CMakeError.log
    )
    EXIT %err%
)

CD /D %BUILDDIR%
cmake --build .
EXIT %ERRORLEVEL%

ENDLOCAL
