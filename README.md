# ProjectGraphs
PowerShell module to draw a graph of c# projects dependencies. It can also spot some kind of issues with libraries and nuget packages references (for example: multiple version of the same library\package).

![Sample screenshot](https://raw.githubusercontent.com/cezarypiatek/ProjectGraphs/master/doc/sample-screen01.jpg)

##How to load module
You have to import ProjectGraphs module into Package Manager Console in Visual Studio. To do that use command

```PowerShell
PM> Import-Module path/ProjectGraphs.psm1
```
where path is the location of ProjectGraphs.psm1 file. 
You can also import ProjectGraphs module in your profile file (after that ProjectGraphs module will be loaded during every startup of Visual Studio). To do that you have to first find out the path to your profile file path. 

```PowerShell
PM> $profile
C:\Users\XXX\Documents\WindowsPowerShell\NuGet_profile.ps1
```

Copy ProjectGraphs.psm1 file into location returened by $profile and add the following code into profile file (If the file doesn't exist you have to create him)

```PowerShell
function Import-LocalModule($module)
{
    $profilePath = $profile | Split-Path -Parent
    $modulePath = Join-Path -Path $profilePath -ChildPath $module
    Import-Module $modulePath -DisableNameChecking -Force
}

Import-LocalModule ProjectGraphs.psm1
```

##How to draw a project graph
To draw a graph of current project dependencies (between projects)
```PowerShell
Generate-ProjectGraph
```
To show dependencies between all projects in solution
```PowerShell
Generate-ProjectGraph -AllProjects
```
To show the dependecies to dll libraries
```PowerShell
Generate-ProjectGraph -IncludeReferences
```

To show the dependecies to nuget packages
```PowerShell
Generate-ProjectGraph -IncludeNugetPackages
```

To exclude given projects from graph (for example Tests)
```PowerShell
Generate-ProjectGraph -Exclude "*Tests"
```

You can combine the above paramaters together. For example to display solution full graph without Test projests
```PowerShell
Generate-ProjectGraph -AllProjects -IncludeReferences  -Exclude "*Tests"
```