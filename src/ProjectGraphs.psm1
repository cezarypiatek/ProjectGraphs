function Clean-String($text){
    $text -replace "\.|\s","_"
}
function GetNodeId($node)
{
    [string]$cleanName = Clean-String (GetNodeLabel $node)
    "$($node.Type)_$($cleanName.ToUpper())"
}

function GetNodeLabel($node)
{
    if($node.Type -eq "Local")
    {
        "$($node.Name)"
    }else{
        "$($node.Name) $($node.Version)"
    }
}

function Generate-DGML
{   [CmdletBinding()]
    param([Parameter(ValueFromPipeline=$true)]$relations)
    begin{
    $nodes = @()
    $nodesIds = @()
@"
<?xml version='1.0' encoding='utf-8'?>
<DirectedGraph xmlns="http://schemas.microsoft.com/vs/2009/dgml">
<Links>
"@
    }
  process{
        $fromId = GetNodeId $_.from
        
        if($nodesIds -cnotcontains $fromId)
        {
            $nodes+=$_.from
            $nodesIds+=$fromId
        }
        if($_.to -ne $null)
        {
            $toId = GetNodeId $_.to
            if($nodesIds -cnotcontains $toId)
            {
                $nodes+=$_.to
                $nodesIds+=$toId
            }
            "<Link Source=`"$fromId`" Target=`"$toId`" />"
        }
  }  
  end{
    "</Links>
<Nodes>"
    foreach($nodeGroup in ($nodes |? {$_.Type -ne "Nuget"} |% {New-Object PSObject -Property $_} | Group-Object Name))
    {
        
        if(($nodeGroup.Count -gt 1))
        {
            foreach($node in $nodeGroup.Group)
            {
                "<Node Id=`"$(GetNodeId $node)`" Label=`"$(GetNodeLabel $node) `($($node.Type)`)`" Category=`"InvalidReference`" />"
            }
        }else{
            foreach($node in $nodeGroup.Group)
            {
                "<Node Id=`"$(GetNodeId $node)`" Label=`"$(GetNodeLabel $node)`" Category=`"$($node.Type)`" />"
            }
        }
    }
   
    foreach($nodeGroup in ($nodes |? {$_.Type -eq "Nuget"} |% {New-Object PSObject -Property $_} | Group-Object Id))
    {
        
        if(($nodeGroup.Count -gt 1))
        {
            foreach($node in $nodeGroup.Group)
            {
                "<Node Id=`"$(GetNodeId $node)`" Label=`"$(GetNodeLabel $node) `(Multiple version`)`" Category=`"NugetMultipleVersion`" />"
            }
        }else{
            foreach($node in $nodeGroup.Group)
            {
                "<Node Id=`"$(GetNodeId $node)`" Label=`"$(GetNodeLabel $node)`" Category=`"$($node.Type)`" />"
            }
        }
    }


"</Nodes>
 <Categories>
      <Category Id=`"Local`" Label=`"Solution Project`" Background=`"White`" />
      <Category Id=`"Nuget`" Label=`"Nuget Package`" Background=`"Orange`"/>
      <Category Id=`"NugetReference`" Label=`"Referenced from Nuget`" Background=`"LightGreen`"/>
      <Category Id=`"LibReference`" Label=`"Referenced from Lib`" Background=`"LightBlue`"/>
      <Category Id=`"FrameworkReference`" Label=`"Referenced from Framework`" Background=`"Aqua`"/>
      <Category Id=`"InvalidReference`" Label=`"Referenced from multiple source or multiple version`" Background=`"Red`"/>
      <Category Id=`"NugetMultipleVersion`" Label=`"Nuget - multiple version installed`" Background=`"Salmon`"/>
   </Categories>
   <Properties>
    <Property Id=`"Expression`" DataType=`"System.String`" />
    <Property Id=`"GroupLabel`" DataType=`"System.String`" />
    <Property Id=`"IsEnabled`" DataType=`"System.Boolean`" />
    <Property Id=`"TargetType`" DataType=`"System.Type`" />
    <Property Id=`"Value`" DataType=`"System.String`" />
    <Property Id=`"ValueLabel`" DataType=`"System.String`" />
  </Properties>
   <Styles>
    <Style TargetType=`"Node`" GroupLabel=`"Solution Project`" ValueLabel=`"True`">
      <Condition Expression=`"HasCategory('Local')`" />
      <Setter Property=`"Background`" Value=`"White`" />
    </Style>
    <Style TargetType=`"Node`" GroupLabel=`"Referenced from Nuget`" ValueLabel=`"True`">
      <Condition Expression=`"HasCategory('NugetReference')`" />
      <Setter Property=`"Background`" Value=`"LightGreen`" />
    </Style>
    <Style TargetType=`"Node`" GroupLabel=`"Referenced from Lib`" ValueLabel=`"True`">
      <Condition Expression=`"HasCategory('LibReference')`" />
      <Setter Property=`"Background`" Value=`"LightBlue`" />
    </Style>
     <Style TargetType=`"Node`" GroupLabel=`"Referenced from Framework`" ValueLabel=`"True`">
      <Condition Expression=`"HasCategory('FrameworkReference')`" />
      <Setter Property=`"Background`" Value=`"Aqua`" />
    </Style>
    <Style TargetType=`"Node`" GroupLabel=`"Referenced from multiple source or multiple version`" ValueLabel=`"True`">
      <Condition Expression=`"HasCategory('InvalidReference')`" />
      <Setter Property=`"Background`" Value=`"Red`" />
    </Style>
     <Style TargetType=`"Node`" GroupLabel=`"Nuget Package`" ValueLabel=`"True`">
      <Condition Expression=`"HasCategory('Nuget')`" />
      <Setter Property=`"Background`" Value=`"Orange`" />
    </Style>
     <Style TargetType=`"Node`" GroupLabel=`"Nuget Package - (multiple version)`" ValueLabel=`"True`">
      <Condition Expression=`"HasCategory('NugetMultipleVersion')`" />
      <Setter Property=`"Background`" Value=`"Salmon`" />
    </Style>
  </Styles>
</DirectedGraph>"
  } 
}

function Create-LocalNode($nodeName)
{
    @{Type="Local"; Name = $nodeName}
}

function Create-NugetNode($package)
{    
    @{Type="Nuget"; Name = $package.Id; Version = $package.Version; Id= $package.Id}
}

function Create-RefNode($lib)
{
    $nodeName = "$($lib.Name) $($lib.Version)"
    if($lib.path -like "*\packages\*"){
         @{Type="NugetReference"; Name = $lib.Name; Version = $lib.Version}
    }
    elseif($lib.path -like "*Program Files*")
    {
        @{Type="FrameworkReference"; Name = $lib.Name; Version = $lib.Version}
    }
    else{
        @{Type="LibReference"; Name = $lib.Name; Version = $lib.Version}
    }
}


function Get-Dependencies(){
    [CmdletBinding()]
    param([switch]$All, $exclude, [switch]$IncludeNuget, [switch]$References)    
    $visited = New-Object 'System.Collections.Generic.HashSet[string]'    
    $getRelations = {param($start)
        if($visited.Contains($start.Name))
        {
            return
        }
        [Void]$visited.Add($start.Name)
        $hasRelations = $false
        $start.Object.References |% {
            
            if($_.SourceProject -ne $null)
            {
                $hasRelations = $true
                @{ From = (Create-LocalNode $start.Name); To = (Create-LocalNode $_.Name)}
                if(!$visited.contains($_.name))
                {
                    & $getrelations $_.sourceproject
                }
            }elseif($References){
                 @{From=  (Create-LocalNode $start.Name); To= (Create-RefNode $_)}
                 $hasRelations = $true
            }      
         }
        
        if($IncludeNuget)
        {
            Get-Package -ProjectName $start.Name |% { 
                    @{From = (Create-LocalNode $start.Name); To= (Create-NugetNode $_)}
                    $hasRelations = $true
                }
        }

        if($hasRelations -eq $false)
        {
            @{From=  (Create-LocalNode $start.Name); To=$null}
        }
    }
   
    Get-Project -All:$All |% {
        if($exclude -and ($_.Name -like $exclude))
        {
            Write-Verbose "Exclude from process: $($_.Name)"
        }else{
            Write-Verbose "Process: $($_.Name)"
            & $getRelations $_        
        }
    }
}

function Get-OutputFileName{
    param([switch]$All)
    $startProject  = Get-Project
    $prefix = ""
    if($All)
    {
        $prefix = "Solution_"
    }
    "$prefix$(Clean-String $startProject.Name).dgml"    
}

function Generate-ProjectGraph{
    [CmdletBinding()]
    param([switch]$AllProjects, $Exclude, [switch]$IncludeNugetPackages,[switch]$IncludeReferences)
    $startTime = Get-Date    
    $outFileName = Get-OutputFileName -All:$AllProjects
    $outputPath = "$($env:TEMP)\$($outFileName)"    
    $dgmlFileContent = Get-Dependencies -All:$AllProjects -exclude $Exclude -IncludeNuget:$IncludeNugetPackages -References:$IncludeReferences| Generate-DGML  
    $dgmlFileContent > $outputPath    
    $DTE.ExecuteCommand(“File.OpenFile”, $outputPath)
    $executionTime = $(Get-Date) - $startTime      
    Write-Warning ("Generating time {0}s" -f $executionTime.TotalSeconds)
}
Export-ModuleMember -Function Generate-ProjectGraph