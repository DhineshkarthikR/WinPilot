@{
    # Exclude Write-Host rule for Terminal UI components that deliberately render to console buffer
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSUseShouldProcessForStateChangingFunctions'
    )

    # Enable all other built-in security, code defect, and style rules
    IncludeRules = @(
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingInvokeExpression',
        'PSPossibleIncorrectComparisonWithNull',
        'PSAvoidUsingEmptyCatchBlock',
        'PSAvoidTrailingWhitespace',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUseOutputTypeCorrectly'
    )
}
