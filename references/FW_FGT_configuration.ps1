
function check_and_load_json () {
    #Comprobamos que si el fichero existe y es un JSON valido
    #Si lo es, lo cargamos en una variable MSobject y la devolvemos al llamante
    param (
        [string[]]$json_file,
        [string[]]$json_path
    )
	if (!(test-path "$($json_path)\$($json_file)" -PathType Leaf)) {
		write-host "File $($json_file) is not present, please make sure the file is in path $($json_path)"
		$salida=1
		$null = return $salida
	}
	try {
		$jsonvars = Get-Content "$($json_path)\$($json_file)" | Out-String | ConvertFrom-Json
	}
	catch {
		write-host "File $($json_file) is not a valid JSON file.`nPlease, check it before running the script again"
		$salida=1
		$null = return $salida
	}
    $null = return $jsonvars
}

function fgt_check_conn () {
    param (
        $fw
    )
    try {
        $conn = Test-Connection -ComputerName $fw.IP -Count 1
    }
    catch {
        $msg = "Error en la conexion con FW $($fw.nombre)"
        fgt_log_error $fw $path $msg
    }
    $null = return $conn
}

function fgt_multi_vdom_old () {
    param () {
        $FGT,
        $mode
    }
#Comprueba si la propiedad "vdom-mode" en //api/v2/cmdb/system/global es igual al valor $state 
#Si es igual devuelve 1, en caso contrario 0
$uri = "https://$($fw.IP)//api/v2/cmdb/system/global/?access_token=$($fw.token)"

$settings = (Invoke-WebRequest -Uri $uri).content | ConvertFrom-Json
if ($settings.results.'vdom-mode' -eq $mode) { return 1
    } else { return 0}
}

function fgt_multi_vdom () {
    param () {
        $FGT,
        $mode
    }
    #Comprueba si la configuraci�n del parametro vdom-mode es igual a $mode
    #Si es igual regresa sin hacer nada y si es diferente lo cambia
    #La funcion asume ciertas credenciales de acceso SSH al FW

    $uri = 'https://'+$fw.IP+'//api/v2/cmdb/system/global/?access_token='+$fw.token
    $vdom_set = ((Invoke-WebRequest -Uri $uri).content | ConvertFrom-Json).results.'vdom-mode'

    if ($vdom_set -ne $mode) {
        $user = "admin"
        $pass = ConvertTo-SecureString "temporal" -AsPlainText -Force
        $cred = [System.Management.Automation.PSCredential]::new($user, $pass)
        $mode = "multi-vdom"
        $sess =  New-SSHsession -ComputerName $fw.IP -Credential $cred -AcceptKey
        $command = "config system global`nset vdom-mode $($mode)`nend`ny"
        $command1 = "config global`nconfig system accprofile`nedit API_USER`nset scope global`nend"
        $null = Invoke-SSHCommand -SSHSession $sess -Command $command
        $null = Remove-SSHSession -SSHSession $sess
        $sess =  New-SSHsession -ComputerName $fw.IP -Credential $cred -AcceptKey
        $null = Invoke-SSHCommand -SSHSession $sess -Command $command1
        $null = Remove-SSHSession -SSHSession $sess
    }
    return
}

function fgt_system_dns () {
    param (
        $FGT,
        $dns
    )
    $uri = "https://$($fw.IP)//api/v2/cmdb/system/dns/?access_token=$($fw.token)"
    $body  = "{ 'primary':'$($dns.DNS1)', 'secondary':'$($dns.DNS2)'}"
    try {
        $null = Invoke-WebRequest -Uri $uri -Method Put -Body $body
    }
    catch {
        $errorct=$Error.Count
        $errormsg = $Error[$errorct-1]
        $msg = "Error en la conexi�n con URI $($uri).`n`n$($errormsg)`n`n"
        fgt_log_error $FGW.nombre $path $msg
    }
}

function fgt_ldap_server () {
    param (
        $FGT,
        $server
    )
    $body = "{
        'name':'$($server.name)',
        'q_origin_key':'$($server.name)',
        'server':'$($server.url)',
        'server-identity-check':'enable',
        'cnid':'$($server.cnid)',
        'dn':'$($server.dn)',
        'type':'$($server.type)',
        'two-factor':'disable',
        'username':'$($server.username)',
        'password':'$($server.pswd)',
        'group-member-check':'user-attr',
        'group-search-base':'',
        'group-object-filter':'(&(objectcategory=group)(member=*))',
        'port':389,
        'member-attr':'memberOf',
        'account-key-filter':'(&(userPrincipalName=%s)(!(UserAccountControl:1.2.840.113556.1.4.803:=2)))'
      }"
    try {
        $status_code = Invoke-WebRequest -Uri https://$($fw.IP)//api/v2/cmdb/user/ldap/?access_token=$($fw.token) -Method Post -ContentType "application/json" -Body $body
    }
    catch {
        $msg = "Ha ocurrido un error al configurar en servidor LDAP"
        fgt_log_error $FGT.nombre $path $msg
    }
    return
}

function fgt_user_group () {
    param (
        $FGT,
        $group
    )
    $body = "{
    	'name':'$($group.name)',
        'q_origin_key':'$($group.name)',
        'group-type':'firewall',
        'member':[
          {
            'name':'$($group.server)',
            'q_origin_key':'$($group.server)'
          }
        ],
        'match':[
          {
            'id':1,
            'q_origin_key':1,
            'server-name':'$($group.server)',
            'group-name':'$($group.remote_group)'
          }
        ]
    }"
    try {
        $status_code = Invoke-WebRequest -Uri https://$($fw.IP)//api/v2/cmdb/user/group/?access_token=$($fw.token) -Method Post -ContentType "application/json" -Body $body   
    }
    catch {
        $msg = "Ha ocurrido un error al configurar el grupo de usuarios"
        fgt_log_error $FGT.nombre $path $msg
    }

    return
}

function fgt_accprofile () {
    param (
        $FGT,
        $user
    )
    $body = "{
        'name':'$($user.name)',
        'q_origin_key':'$($user.name)',
        'scope':'vdom',
        'secfabgrp':'$($user.sec_fabric)',
        'ftviewgrp':'$($user.fortiview)',
        'authgrp':'read',
        'sysgrp':'$($user.system)',
        'netgrp':'$($user.network)',
        'loggrp':'$($user.log)',
        'fwgrp':'$($user.firewall)',
        'vpngrp':'$($user.vpn)',
        'utmgrp':'$($user.user_device)',
        'wifi':'$($user.wifi_sw)',
        'admintimeout-override':'disable',
        'admintimeout':10,
        'system-diagnostics':'enable'
        }"
    try {
        $status_code = Invoke-WebRequest -Uri https://$($fw.IP)//api/v2/cmdb/system/accprofile/?access_token=$($fw.token) -Method Post -ContentType "application/json" -Body $body 
    }
    catch {
        $msg = "Ha ocurrido un error al configurar el perfil de permisos"
        fgt_log_error $FGT.nombre $path $msg
    }

    return
}

function fgt_admin_user () {
    param (
        $FGT,
        $user
    )
    $body = "{
        'name':'$($user.name)',
        'remote-auth':'enable',
        'remote-group':'$($user.remote_group)',
        'accprofile':'$($user.accprofile)',
        'allow-remove-admin-session':'enable',
        'two-factor':'disable'
        }"
    $Uri = 'https://'+$fw.IP+'//api/v2/cmdb/system/admin/?access_token='+$fw.token
    try {
        $null = Invoke-WebRequest -Uri $Uri -Method Post -ContentType "application/json" -Body $body 
    }
    catch {
        $msg = "Ha ocurrido un error al configurar el usuario administrador $($user.name)`n$($Uri)`n$($body)"
        fgt_log_error $fw.name $path $msg
    }
    return
}

function fgt_vdom_old () {
    #Creamos un nuevo VDOM en un FW, si no existe
    param () {
        $fw,
        $vdom
    }
    $salida = 0

    #Si el VDOM existe regresamos sin hacer nada
    $Uri = 'https://'+$fw.IP+'//api/v2/cmdb/system/vdom/?access_token='+$fw.token
    $settings = (Invoke-WebRequest -uri $Uri).Content | ConvertFrom-Json
    if ($null -ne ($settings.results.name | Where-Object {$_ -eq $vdom.nombre} ) ) {
        $msg = "El VDOM $($vdom.nombre) ya existe en el equipo $($fw.nombre)"
        fgt_log_error $fw.nombre $path $msg
        return $salida
    }
    
    #Si no existe, lo creamos y escribimos la accion a log
    $body = "{ 'name':'$($vdom.nombre)', 'short-name':'$($vdom.nombre)', 'vcluster-id':0, 'flag':0 }"
    try {
        $status_code = Invoke-WebRequest -uri https://$($fw.IP)//api/v2/cmdb/system/vdom/?access_token=$($fw.token) -Method Post -Body $body
    }
    catch {
        $salida = 1
        $msg = "Ha ocurrido un error al configurar"
        fgt_log_error $fw.name $path $msg 
    }
    if ($status_code.StatusCode -ne 200) {
        $salida = 1
        $msg = "Ha ocurrido un error al configurar.`n`n$($status_code.Content)`n`n"
        fgt_log_error $fw.name $path $msg
    }
    return $salida
}

function fgt_vdom () {
    #Creamos un nuevo VDOM en un FW, si no existe y damos permisos al usuario API para actuar sobre el mismo
    #En esta funcion se asumen unas credenciales de SSH temporales para acceder al FW
    param () {
        $FGT,
        $vdom
    }
    $user = "admin"
    $pass = ConvertTo-SecureString "temporal" -AsPlainText -Force
    $cred = [System.Management.Automation.PSCredential]::new($user, $pass)

    #Comprobamos si el VDOM existe
    $command = "config global`nget system vdom-property"
    $sess =  New-SSHsession -ComputerName $fw.IP -Credential $cred -AcceptKey
    $out = Invoke-SSHCommand -SSHSession $sess -Command $command
     #Si existe continuamos, si no existe lo creamos  
      
    if (!($out.Output -match $vdom.nombre )) { 
        $cmd_vdom = "config vdom`nedit $($vdom.nombre)`nnext`nend"
        $null =  Invoke-SSHCommand -SSHSession $sess -Command $cmd_vdom
    }

    #Comprobamos si el usuario de API tiene permisos, si tiene continuamos, si no tiene se lo a�adimos
    $command = "config global`nshow system api-user"
    $out = Invoke-SSHCommand -SSHSession $sess -Command $command
    foreach ($line in $out.Output) {
        if ($line -match "set vdom") {
            $set_vdom = $line
        }
    }
    if (!($set_vdom -match $vdom.nombre)) {
        foreach ($line in $out.Output) {
            if ($line -match "edit") {$api_user = $line.Trim().split(" ")[1]}
        }
        $set_vdom += ' '+$vdom.nombre
        $command = "config global`nconfig system api-user`nedit $($api_user)`n$($set_vdom)`nnext`nend"
        $null = Invoke-SSHCommand -SSHSession $sess -Command $command
    }
        $null = Remove-SSHSession -SSHSession $sess
    return
}
 
function fgt_zone () {
    #Crea una nueva zona en un Firewall, para el VDOM indicado
    param () {
        $FGT,
        $zona
    }
    $ints = $zona.ifs.Split(",")
    $ints
    $body = "{
        'name':'$($zona.nombre)',
        'intrazone':'deny',
        'interface':["
    if ($ints.count -eq 1) { 
        $body += "{'interface-name':'$($ints)'}]}" 
    } else {
        $j=0
        foreach ($int in $ints) {
            $body += "{'interface-name':'$($int)'}"
            if ($j -lt ($ints.count - 1)){
                $body += ","
                $j++
            }
        }
        $body += "]}"
    }
    $URI = 'https://'+$fw.IP+'/api/v2/cmdb/system/zone/?access_token='+$fw.token
    try {
        $null = Invoke-WebRequest -Uri $URI -Method Post -Body $body
    }
    catch {
        write-host $body
        $msg = "No se pudo configurar la zona $($zona.nombre)"
        $null = fgt_log_error $fw.nombre $path $msg
    }
    return
}

function fgt_interface () {
    #Crea un interfaz con las propiedades dadas
    param (
        $FGT,
        $interface,
        $vdom
    )
    switch ($interface.tipo) {
        "aggregate" {
            
            $vdom = "root"
            $body = "{
                'name':'$($interface.nombre)',
                'vdom':'$($vdom)',
                'mode':'static',
                'ip':'0.0.0.0 0.0.0.0',
                'type':'aggregate',
                'member':["
            $members = $interface.members.Split(".")
        
            for ($i=0;$i -eq ($members.count)-2; $i++){
                $body += "`n  {'interface-name':'$($members[$i])'},"
            }
            $body += "`n  {'interface-name':'$($members[$count-1])'}
                ],
                'lacp-mode':'active',
                'lacp-ha-slave':'enable'}"
         }
        "vlan" {
            $body = "{
                'name':'$($interface.nombre)',
                'vdom':'root',
                'ip':'$($interface.ip)',
                'allowaccess':'ping',
                'type':'$($interface.tipo)',
                'interface':'$($interface.parent)',
                'vlan-protocol':'8021q',
                'vlanid':'$($interface.vlan)',
                'role':'lan',
                'status':'down'}"
            
        }
        "vdom-link" {
            $body = "{
                'name':'$($interface.nombre)',
                'vdom':'$vdom',
                'ip':'$($interface.ip)',
                'allowaccess':'ping',
                'type':'$($interface.tipo)'}"
        }
    }
    $URI = 'https://'+$fw.IP+'//api/v2/cmdb/system/interface/?access_token='+$fw.token
    
    #Creamos primero todos los interfaces en el VDOM root para moverlos despu�s si corresponde
    try {  
        $status_code = Invoke-WebRequest -uri $URI -Method Post -Body $body  
    }
    catch {
        $msg = "No se ha podido configurar el interfaz $($interface.nombre)"
        $null = fgt_log_error $FGT.nombre $path $msg
    }

    #Si el interfaz debe estar en un vdom distinto a root lo movemos
    if ($vdom.nombre -ne "root" -and $interface.tipo -eq "vlan") {
        $user = "admin"
        $pass = ConvertTo-SecureString "temporal" -AsPlainText -Force
        $cred = [System.Management.Automation.PSCredential]::new($user, $pass)
        $sess =  New-SSHsession -ComputerName $fw.IP -Credential $cred -AcceptKey
        $command = "config global`nconfig system interface`nedit $($interface.nombre)`nset vdom $($vdom)`nnext`nend"
        $null = Invoke-SSHCommand -SSHSession $sess -Command $command
        $null = Remove-SSHSession -SSHSession $sess
    }

    return
}

function fgt_sdwan_if () {
    param (
        $FGT,
        $if
    )
    $uri = 'https://'+$fw.ip+'//api/v2/cmdb/system/sdwan/?access_token='+$fw.token
    If ($fw.tipo -eq "I"){$uri += '&vdom=WAN'}
    $body = "{'members':[{'seq-num':1,'interface':'$($if.nombre)','zone':'virtual-wan-link','gateway':'$($if.gw)','source':'0.0.0.0','status':'enable'}]}"
    try {
        $null= Invoke-WebRequest -Uri $uri -Method Put -Body $body
    }
    catch {
        $msg = "No ha sido posible incluir el interfaz $($if.nombre) a la zona SDWAN:"
        $null = fgt_log_error $FGT.nombre $path $msg
    }
}

function fgt_fw_address () {
    param (
        $FGT,
        $address
    )
    if ($address.tipo -eq "VLAN"){
        if ( $address.ip -eq "0.0.0.0 0.0.0.0") {return}
        $address.ip
        $ip=[ipaddress]$address.ip.split(" ")[0]
        $mask=[ipaddress]$address.ip.split(" ")[1]
        #Calculamos la IP de red
        $subnet=[ipaddress]($ip.Address -band $mask.Address)
        #Creamos la variable de direcci�n de red con la IP de red y la m�scara decimal
        $red="$($subnet.IPAddressToString) "+"$($mask.IPAddressToString)"
        #Creamos el nombre como N_[IP de red]-[m�scara binaria]-[Nombre del interfaz]
        $nombre = "N-$($subnet.IPAddressToString)_$((([convert]::ToString($mask.Address, 2)) -replace 0, $null).length)-$($address.nombre)"
        $body = "{ 'name':'$nombre', 'subnet':'$($red)', 'type':'ipmask' }"
        $vdom = "*"
    } else {
        $body = "{ 'name':'$($address.nombre)', 'subnet':'$($address.red)', 'type':'$($address.tipo)' }"
        $vdom = $address.vdom
    }
    $URI = 'https://'+$fw.IP+'/api/v2/cmdb/firewall/address/?access_token='+$fw.token+'&vdom='+$vdom
    try {
        Invoke-WebRequest -Uri $URI -Method Post -Body $body
    }
    catch {
        if ($address.tipo -eq "VLAN") {
            $msg = "Ha habido un problema en la configuraci�n del objeto $($nombre):`n`n$($status_code.Content)"
        } else {$msg = "Ha habido un problema en la configuraci�n del objeto $($address.nombre):`n`n$($status_code.Content)"}
        $null = fgt_log_error $FGT.nombre $path $msg
    }
    return 
}

function fgt_fw_addrgrp () {
    param (
        $FGT,
        $addrgrp
    )
    $members = $addrgrp.members.split(",")
    $body = "{'name':'$($addrgrp.nombre)', 'member':["
        for ($i=0; $i -lt ($members.count)-1; $i++) {
            $body += "{'name':'$($members[$i])'},"
        }
        $body += "{'name':'$($members[$count-1])'}]"
    if ($null -ne $addrgrp.exclude) {
        $body += ",'exclude':'enable','exclude-member':["
        $exmembers = $addrgrp.exmembers.split(",")
        $j=0
        foreach ($exmember in $exmembers) {
            $body += "{'name':'$($exmember)'}"
            if ($j -lt ($exmembers.count-1)) {
                $body += ","
                $j++
            }
        } 
        $body+="]"
    }
    $body +="}"
    $uri = 'https://'+$fw.IP+'/api/v2/cmdb/firewall/addrgrp/?access_token='+$fw.token+'&vdom='+$addrgrp.vdom
    try {
        $status_code=Invoke-WebRequest -Uri $uri -Method Post -Body $body
    }
    catch {
        $msg = "Ha habido un problema en la configuraci�n del grupo $($addrgrp.nombre)."
        $null = fgt_log_error $FGT.nombre $path $msg
    }
    return
}

function fgt_fw_svcs () {
    param (
        $FGT,
        $svc
    )
    #Estar�a bien considerar todas las posibilidades en los servicios, por ahora no es necesario
    $body = "{
        'name':'$($svc.nombre)',
        'category':'$($svc.category)',
        'protocol':'$($svc.protocol)',
        'fqdn':'',
        'tcp-portrange':'$($svc.tcpportrange)',
        'udp-portrange':'$($svc.udpportrange)'
    }"
    $uri = 'https://'+$fw.IP+'/api/v2/cmdb/firewall.service/custom/?access_token='+$fw.token+'&vdom=HOSP,WAN,ADM'
    try {
        Invoke-WebRequest -Uri $uri -Method Post -Body $body
    }
    catch {
        $msg = "Ha habido un error en la configuraci�n del servicio $($svc.nombre)"
        $null = fgt_log_error $FGT.nombre $path $msg
    }
    return
}

function fgt_fw_policy () {
    param (
        $FGT,
        $policy
    )
    #Para el nombre de la pol�tica, tenemos en cuenta que hay un l�mite de 36 caracteres
    $name = "$($policy.action.ToUpper())-$($policy.SRC.ToLower().Replace('net_',''))_to_$($policy.DST.ToLower().Replace('net_',''))"
    if ($name.Length -gt 35) {
        $name = $name.Substring(0,34)
    }
    if ($hit.SRC -like "net_*") {
        $intf = $fw.VDOM.ifs | Where-Object {$_.nombre -eq $hit.SRC.Replace("net_","").ToUpper()}
    	$ip = [ipaddress]$intf.ip.Split(" ")[0]
	    $mask = [ipaddress]$intf.ip.Split(" ")[1]
    	$subnet = [ipaddress]($ip.Address -band $mask.Address)
	    $SRC = "N-$($subnet.IPAddressToString)_$((([convert]::ToString($mask.Address, 2)) -replace 0, $null).length)"+"-$($intf.nombre)"
    } else {$SRC=$hit.SRC}
    if ($hit.DST -like "net_*") {
        $intf = $fw.VDOM.ifs | Where-Object {$_.nombre -eq $hit.DST.Replace("net_","").ToUpper()}
    	$ip = [ipaddress]$intf.ip.Split(" ")[0]
	    $mask = [ipaddress]$intf.ip.Split(" ")[1]
    	$subnet = [ipaddress]($ip.Address -band $mask.Address)
	    $DST = "N-$($subnet.IPAddressToString)_$((([convert]::ToString($mask.Address, 2)) -replace 0, $null).length)-$($intf.nombre)"
    } else {$DST=$hit.DST}
    $body = " {
        'status':'enable',
        'name':'$($name)',
        'srcintf':[
          {
            'name':'$($hit.srcint)'
          }
        ],
        'dstintf':[
          {
            'name':'$($hit.dstint)'
          }
        ],
        'srcaddr':[
          {
            'name':'$($SRC)'
            }
        ],
        'dstaddr':[
          {
            'name':'$($DST)'
          }
        ],
        'action':'$($hit.ACTION.ToLower())',
        'schedule':'always',
        'logtraffic': 'all',
        'logtraffic-start': 'enable',
        'service':[
          {
            'name':'$($hit.SVC.ToUpper())'
          }
        ]
      }"
    $URI = 'https://'+$fw.IP+'/api/v2/cmdb/firewall/policy/?access_token='+$fw.token+'&vdom='+$hit.vdom
    try {
        $null=Invoke-WebRequest -Uri $URI -Method Post -Body $body
    }
    catch {
        $msg = "Ha habido un problema en la configuraci�n de la pol�tica $($name).`n$($uri)`n$($body)"
        $null = fgt_log_error $FGT.nombre $path $msg
    }
    return
}

function fgt_log_error () {
    param (
        $device,
        $path,
        $msg
        )
    $dia = (Get-Date -Format d).Replace("/","-")
    $hora = Get-Date -Format G 
    #Si no existe el fichero de logs para el equipo para el que se ha obtenido el error, se crea.
    if (!(test-path "$($path)\$($device)_$($dia).log" -PathType Leaf)) {
		$null = New-Item -Path "$($path)\$($device)_$($dia).log" -ItemType File
	}
    #Una vez confirmado que el fichero existe, se a�ade una l�nea al final con el formato: datetime, device name, msg
    $null = Add-Content -Path "$($path)\$($device)_$($dia).log" -Value "$($hora);$($device);$($msg)"
}

function fgt_check_token () {
    param (
        $FGW
    )
    $uri = "https://$($FGW.ip)//api/v2/cmdb/system/api-user/?access_token=$($FGW.token)"
    $status = 0
    try {
        if ((Invoke-WebRequest -Uri $uri).StatusCode -ne 200) {
            $status = 1 
            $msg = "Ha habido un problema en la validaci�n del token para el FW $($FGW.nombre)"
            fgt_log_error $FGW.nombre $path $msg
        }
    }
    catch {
        Write-Host "No ha sido posible conectar con el interfaz API del FW $($FGW.nombre)"
        $status = 1
        $errorct=$Error.Count
        $errormsg = $Error[$errorct-1]
        $msg = "Error en la conexi�n con URI $($uri).`n`n$($errormsg)`n`n"
        fgt_log_error $FGW.nombre $path $msg
    }
    $null = return $status
}

$inicio = Get-Date
$salida = 0
$fwfile = "config_FWs.json"
$varsfile = "var_globales.json"
$typeIfile = "pols_type_I.json"
$typeIIfile = "pols_type_II.json"
$path = get-location
#Comprobamos que los ficheros de datos existen y, si existen, cargamos los datos de los ficheros en variables
$fws = check_and_load_json $fwfile $path
$vars = check_and_load_json $varsfile $path
$archI = check_and_load_json $typeIfile $path
$archII = check_and_load_json $typeIIfile $path


#Confiamos en todos los certificados, para evitar los errores por los certificados autofirmados de los Firewalls
#Lanzamos la instancia dentro de un try para evitar un error si ya se ha ejecutadoo esta parte del c�digo
#anteriormente en la misma sesi�n de PS
$trustcert = @'
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
'@

try {
    Add-Type -TypeDefinition $trustcert
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy    
}
catch {
}


#Para cada FW en la lista, hacemos comprobaciones, configuramos los datos y sacamos el resultado a un fichero de logs
:fws foreach ($fw in $fws.FWS) {
    write-host "Se comienza la configuracion del equipo $($fw.nombre)"
    #Comprobamos que llegamos al equipo
    $conn = fgt_check_conn $fw
    if ($null -eq $conn) {
        write-host "No es posible conectar con el firewall"
        continue
    }
    #Comprobamos que funciona el token de API
    if ((fgt_check_token $fw) -eq 1) {
        Write-Host "Ha habido un problema con el token al conectar con el firewall"
        continue
    }

    #Hacemos la configuraci�n b�sica
    #DNS
    $null = fgt_system_dns $fw $vars.DNS
    #Acceso LDAP
        #Primero definimos el servidor LDAP
    $null = fgt_ldap_server $fw $vars.LDAP.server
        #Definimos los grupos de AD de los administradores
    foreach ($group in $vars.LDAP.user_groups) {
        $null = fgt_user_group $fw $group
    }
        #Creamos los perfiles de administraci�n
    foreach ($profile in $vars.LDAP.acc_profile) {
        $null = fgt_accprofile $fw $profile
    }
        #Creamos los usuarios relacionando grupos de usuarios en AD con perfiles de privilegios
    foreach ($user in $vars.LDAP.users) {
        $null = fgt_admin_user $fw $user
    }

    #Activamos la funcionalidad de multi-vdom
    $null = fgt_multi_vdom $fw "multi-vdom"


    #Configuramos los VDOM y sus interfaces
    #Configuramos primero los agregados
    foreach ($aggr in $fw.LACP.aggregates) {
        fgt_interface $fw $aggr $aggr.vdom
    }

    foreach ($vdom in $fw.VDOM) {
        #Si el VDOM es diferente del VDOM root, lo creamos
        if ($vdom.nombre -ne "root") {$null = fgt_vdom $fw $vdom.nombre}
        #
        #Configuramos los interfaces que pertenecen al VDOM
        #Y creamos los objetos address seg�n los interfaces del FW
        foreach ($intf in $vdom.ifs) {
            fgt_interface $fw $intf $vdom.nombre
            fgt_fw_address $fw $intf
        }
    }

    #Si el centro es del modelo de arquitectura I, configuramos:
    if ($fw.tipo -eq "I") {
        #A�adimos el interfaz WAN a la zona SDWAN por defecto
        #De los interfaces del VDOM WAN, seleccionamos el �nico que tenga una IP definida como GW:
        $wanifs = $fw.VDOM | Where-Object { $_.nombre -eq "WAN" }
        $sdwanif = $wanifs.ifs | Where-Object { $null -ne $_.gw }
        $null = fgt_sdwan_if $fw $sdwanif 
        #Los objetos address gen�ricos
        foreach ($addr in $archI.address) { $null = fgt_fw_address $fw $addr $addr.vdom}
        #Los grupos de direcciones
        foreach ($addrgrp in $archI.addrgrps) {$null = fgt_fw_addrgrp $fw $addrgrp}
        #Los servicios personalizados
        foreach ($svc in $archI.svcs) { $null = fgt_fw_svcs $fw $svc}
        #Las pol�ticas que aplican al centro
        #Dentro de cada VDOM, buscamos las pol�ticas que tengan como extremos la red configurada para cada uno de los interfaces del FW o "all" en ambos extremos
        foreach ($vdom in $fw.VDOM) {
            foreach ($intf in $vdom.ifs) {
                $net_name = "net_"+$intf.nombre.ToLower()
                $srchits = $archI.politicas | Where-Object {($_.VDOM -eq "WAN") -or (($_.VDOM -eq $vdom.nombre) -and ($_.src -eq $net_name))}
                if ($null -ne $srchits) {
                    foreach ($hit in $srchits) {fgt_fw_policy $fw $hit}
                }
                $dsthits = $archI.politicas | Where-Object {($_.VDOM -eq "WAN") -or ($_.VDOM -eq $vdom.nombre) -or (($_.VDOM -eq "WAN") -and ($_.dst -eq $net_name))}
                if ($null -ne $dsthits) {
                    foreach ($hit in $dsthits) {fgt_fw_policy $fw $hit}
                }
                $anyhits = $archI.politicas | Where-Object {($_.VDOM -eq $vdom.nombre) -and ($_.src -eq "all") -and ($_.dst -eq "all")}
                if ($null -ne $anyhits) {
                    foreach ($hit in $anyhits) {fgt_fw_policy $fw $hit}
                }     
            }
        }
    }

    #Si el centro tiene arquitectura modelo II, configuramos:
    if ($fw.tipo -eq "II") {
        #Las zonas con sus interfaces
        foreach ($zona in $fw.VDOM[0].zonas) {
            $null = fgt_zone $fw $zona
        }
        #A�adimos el interfaz WAN a la zona SDWAN por defecto
        #De los interfaces del VDOM root, seleccionamos el �nico que tenga una IP definida como GW:
        $wanifs = $fw.VDOM | Where-Object { $_.nombre -eq "root" }
        $sdwanif = $wanifs.ifs | Where-Object { $null -ne $_.gw }
        $null = fgt_sdwan_if $fw $sdwanif 
        #Los objetos address gen�ricos
        foreach ($addr in $archII.address) { $null = fgt_fw_address $fw $addr $addr.vdom}
        #Los grupos de direcciones
        foreach ($addrgrp in $archII.addrgrps) {$null = fgt_fw_addrgrp $fw $addrgrp}
        #Los servicios personalizados
        foreach ($svc in $archII.$svcs) { $null = fgt_fw_svcs $fw $svcs}
        #Las pol�ticas que aplican al centro:
        #Dentro de cada VDOM
        foreach ($vdom in $fw.VDOM) {
            foreach ($interface in $vdom.ifs) {
                $net_name = "net_"+$interface.nombre.ToLower()
                $srchits = $archII.politicas | Where-Object {($_.VDOM -eq $vdom.nombre) -and ($_.src -eq $net_name)}
                if ($null -ne $srchits) {
                    foreach ($hit in $srchits) {fgt_fw_policy $fw $hit}
                }
                $dsthits = $archII.politicas | Where-Object {($_.VDOM -eq $vdom.nombre) -and ($_.dst -eq $net_name)}
                if ($null -ne $dsthits) {
                    foreach ($hit in $dsthits) {fgt_fw_policy $fw $hit}
                }
                $anyhits = $archII.politicas | Where-Object {($_.VDOM -eq $vdom.nombre) -and (($_.src -eq "all") -or ($_.dst -eq "all"))}
                if ($null -ne $anyhits) {
                    foreach ($hit in $anyhits) {fgt_fw_policy $fw $hit}
                }     
            }
        }
    }
}
 
#Terminadas las configuraciones sacamos un mensaje por pantalla con el tiempo que ha tardado
$delay = (get-date)-$inicio
$horas = $delay.Hours
$mins = $delay.Minutes
$secs = $delay.Seconds
write-host "Se ha finalizado la configuraci�n de los equipos .... en $($horas)h:$($mins)m:$($secs)s"