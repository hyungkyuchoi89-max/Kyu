@rem Gradle wrapper launcher for WordWake.
@echo off
setlocal

set DIRNAME=%~dp0
if "%DIRNAME%" == "" set DIRNAME=.\

if "%JAVA_HOME%" == "" goto findJavaFromPath
set JAVA_EXE=%JAVA_HOME%\bin\java.exe
if exist "%JAVA_EXE%" goto execute

:findJavaFromPath
set JAVA_EXE=java.exe

:execute
"%JAVA_EXE%" -Dorg.gradle.appname=gradlew -classpath "%DIRNAME%gradle\wrapper\gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain %*

endlocal
