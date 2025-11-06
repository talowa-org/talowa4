@echo off
echo ========================================
echo PHASE 3C: Current Issues Analysis
echo ========================================
echo.

echo 🔍 Running comprehensive analysis...
flutter analyze --no-congratulate > current_analysis.txt 2>&1

echo.
echo 📊 Issue Summary:
findstr /C:"issues found" current_analysis.txt

echo.
echo 🎯 Top Error Categories:
echo.
echo Undefined Getters:
findstr /C:"undefined_getter" current_analysis.txt | find /C "undefined_getter"

echo Undefined Methods:
findstr /C:"undefined_method" current_analysis.txt | find /C "undefined_method"

echo Missing Required Arguments:
findstr /C:"missing_required_argument" current_analysis.txt | find /C "missing_required_argument"

echo Extra Positional Arguments:
findstr /C:"extra_positional_arguments" current_analysis.txt | find /C "extra_positional_arguments"

echo Deprecated Member Use:
findstr /C:"deprecated_member_use" current_analysis.txt | find /C "deprecated_member_use"

echo Unused Elements:
findstr /C:"unused_element" current_analysis.txt | find /C "unused_element"

echo Unused Variables:
findstr /C:"unused_local_variable" current_analysis.txt | find /C "unused_local_variable"

echo Unused Fields:
findstr /C:"unused_field" current_analysis.txt | find /C "unused_field"

echo Unused Imports:
findstr /C:"unused_import" current_analysis.txt | find /C "unused_import"

echo.
echo 📋 Ready for Phase 3C targeted fixes...

pause