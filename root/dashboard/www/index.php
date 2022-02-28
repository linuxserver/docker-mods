<?php
    function GetHeader() {
        return <<<HTML
            <style type="text/css">
            @import url("https://use.fontawesome.com/releases/v5.15.0/css/all.css");
                .status-div {
                    display: inline-block;
                    padding-right: 20px;
                    text-align: center;
                    vertical-align: top;
                }
                .status-text {
                    font-size: 15px;
                }
                .link-text {
                    font-weight: bold;
                }
                .left-text {
                    text-align: left;
                }
                td {
                    padding-right: 20px;
                }
                .far, .fas {
                    font-family: "Font Awesome 5 Free" !important;
                }
                .fa-exclamation-circle,.fa-check-circle, .fa-info-circle, .fa-edit, .fa-lock {
                    font-size:20px;
                    padding: 2px;
                }
                .fa-check-circle, .fa-lock {
                    color: #5DB56A;
                }
                .fa-exclamation-circle {
                    color: #FF303E;
                }
                .fa-info-circle:hover{
                    color: gray;
                    cursor: help;
                }
                .fa-exclamation-circle:hover{
                    color: gray;
                    cursor: help;
                }
            </style>
        HTML;
    }

    function GetProxies() {
        $output = shell_exec("python3 /dashboard/swag-proxies.py");
        $results = json_decode($output);
        $status = "";
        $index = 0;
        foreach($results as $result => $data){
            $tr_class = ($index % 2 == 0) ? 'shaded' : '';
            $status .= '<tr class="'.$tr_class.'"><td class="left-text"><span class="status-text">'.$result.'</span></td><td class="align-td">';
            if ($data->status == 1) {
                $status .= '<i class="fas fa-check-circle"></i>';
            } else {
                $status .= '<i class="fas fa-exclamation-circle" title="The SWAG container can\'t reach '.$result.'"></i>';
            }
            $status .= '</td><td>';
            if (!empty($data->locations)) {
                $locations = $data->locations;
                $location = implode(",", $locations);
                $status .= '<i class="fas fa-check-circle"></i></td><td class="left-text"><span class="status-text">'.$location.'</span></td>';
            } else {
                $error = 'Unable to locate the proxy config for '.$result.', it must use the following structure:'.PHP_EOL;
                $error .= '&#09;set $upstream_app <container/address>;'.PHP_EOL;
                $error .= '&#09;set $upstream_port <port>;'.PHP_EOL;
                $error .= '&#09;set $upstream_proto <protocol>;'.PHP_EOL;
                $error .= '&#09;proxy_pass $upstream_proto://$upstream_app:$upstream_port;'.PHP_EOL;
                $status .= '<i class="fas fa-exclamation-circle" title="'.$error.'"></i></td><td></td>';
            }
            $status .= '</tr>';
            $index++;
        }
        return <<<HTML
            <div class="wrap-panel status-div">
                <div>
                    <h2>Proxies</h2>
                    <table class="table-hover">
                        <thead>
                            <tr>
                                <td><h3>Application</h3></td>
                                <td><h3>Available</h3></td>
                                <td><h3>Proxied</h3></td>
                                <td><h3>Location</h3></td>
                            </tr>
                        </thead>
                        <tbody class="tbody-data">
                            {$status}
                        </tbody>
                    </table>
                    <br/>
                </div>
                <br/>
            </div>
        HTML;
    }

    function GetF2B($f2bdb = '/config/fail2ban/fail2ban.sqlite3') {
        if (!file_exists($f2bdb)) return false;
        $output = shell_exec("python3 /dashboard/swag-f2b.py {$f2bdb}");
        $jails = json_decode($output, true);
        $status = "";
        $index = 0;
        foreach($jails as $jail){
            $tr_class = ($index % 2 == 0) ? 'shaded' : '';
            $data = ($jail["data"]) ? ' <i title="'.htmlspecialchars($jail["data"]).'" class="fas fa-info-circle"></i>' : '';
            $status .= '<tr class="'.$tr_class.'"><td class="left-text"><span class="status-text">'.$jail["name"].'</span></td>';
            $status .= '<td><span class="status-text">'.$jail["bans"].'</span></td>';
            $status .= '<td><span class="status-text">'.$jail["last_ban"].'</span>'.$data.'</td></tr>';
            $index++;
        }
        return <<<HTML
            <div class="wrap-panel status-div">
                <div>
                    <h2>Fail2Ban</h2>
                    <table class="table-hover">
                        <thead>
                            <tr>
                                <td><h3>Jail</h3></td>
                                <td><h3>Bans</h3></td>
                                <td><h3>Last</h3></td>
                            </tr>
                        </thead>
                        <tbody class="tbody-data">
                            {$status}
                        </tbody>
                    </table>
                    <br/>
                </div>
                <br/>
            </div>
        HTML;
    }

    function GetTemplates() {
        $tooltip = "";
        $files = "";
        $counter = 1;
        $conf_locations = array(
            "subdomain.conf" => "https://github.com/linuxserver/reverse-proxy-confs/blob/master/",
            "subfolder.conf" => "https://github.com/linuxserver/reverse-proxy-confs/blob/master/",
            "dashboard.subdomain.conf" => "https://github.com/linuxserver/docker-mods/blob/swag-dashboard/root/dashboard/",
        );
        $output = shell_exec("/etc/cont-init.d/70-templates");

        foreach(explode(PHP_EOL, $output) as $line) {
            if(substr($line, 0, 1) === "*"){
                $tooltip .= str_replace("*", "", $line).PHP_EOL;
            } elseif(substr($line, 0, 1) === "/") {
                $tr_class = ($counter % 2 == 0) ? 'shaded' : '';
                $files .= '<tr class="'.$tr_class.'"><td class="left-text"><span class="status-text">'.htmlspecialchars($line).'</span></td>';
                $file_name = substr($line, strrpos($line, '/') + 1);
                $link = "https://github.com/linuxserver/docker-swag/blob/master/root/defaults/".$file_name;
                foreach($conf_locations as $key=>$value) {
                    if (strpos($file_name, $key) !== false) {
                        $link = $value.$file_name;
                    }
                }           
                if (strpos($file_name, 'subdomain.conf') !== false or strpos($file_name, 'subfolder.conf') !== false) {
                    $link .= '.sample';
                }
                $files .= '<td><a href="'.$link.'"><i class="fas fa-edit"></i></a></td></tr>';
                $counter++;
            }
        }
        if(empty($files)) {
            return "";
        }
        return <<<HTML
            <div class="wrap-panel status-div">
                <div>
                    <h2>Version Updates <i class="fas fa-info-circle" title="{$tooltip}"></i></h2>
                    <table class="table-hover">
                        <tbody class="tbody-data">
                            {$files}
                        </tbody>
                    </table>
                    <br/>
                </div>
                <br/>
            </div>
        HTML;
    }

    function GetAnnouncements() {
        $feed_url = 'https://info.linuxserver.io/index.xml';
        $max_entries = 8;
        $xml = simplexml_load_string(file_get_contents($feed_url));
        $output = "";
        $entries = $xml->channel->item;
        $counter = 1;

        foreach($entries as $root) {
            $date = date('Y-m-d', strtotime($root->pubDate));
            $output .= '<tr><td><span class="status-text">'.htmlspecialchars($date).'</span></td>';
            $output .= '<td class="link-text left-text"><span class="status-text"><a href="'.htmlspecialchars($root->link).'">'.htmlspecialchars($root->title).'</a></span></td></tr>';
            if($counter >= $max_entries) {
                break;
            }
            $counter++;
        }
        return <<<HTML
            <div class="wrap-panel status-div">
                <div>
                    <h2>Announcements</h2>
                    <table class="table-hover">
                        <tbody class="tbody-data">
                            {$output}
                        </tbody>
                    </table>
                    <br/>
                </div>
                <br/>
            </div>
        HTML;
    }

    function GetLinks() {
        return <<<HTML
            <div class="wrap-panel status-div">
                <div>
                    <h2>Useful Links</h2>
                    <table class="table-hover">
                        <tbody class="tbody-data">
                            <tr><td class="link-text left-text"><span class="status-text"><a href="https://www.linuxserver.io/">Linuxserver.io</a></span></td></tr>
                            <tr><td class="link-text left-text"><span class="status-text"><a href="https://github.com/linuxserver/docker-swag">SWAG Container</a></span></td></tr>
                            <tr><td class="link-text left-text"><span class="status-text"><a href="https://docs.linuxserver.io/general/swag">SWAG Setup</a></span></td></tr>
                            <tr><td class="link-text left-text"><span class="status-text"><a href="https://www.linuxserver.io/support">Get Support</a></span></td></tr>
                            <tr><td class="link-text left-text"><span class="status-text"><a href="https://opencollective.com/linuxserver/donate">Donate</a></span></td></tr>
                        </tbody>
                    </table>
                    <br/>
                </div>
                <br/>
            </div>
        HTML;
    }

    function GetGoaccess() {
        $dbip = '/config/geoip2db/dbip-country-lite.mmdb';
        $maxmind = '/config/geoip2db/GeoLite2-City.mmdb';
        if (file_exists($dbip) and file_exists($maxmind)):
            $geodb = (filemtime($dbip) > filemtime($maxmind)) ? '--geoip-database='.$dbip : '--geoip-database='.$maxmind;
        elseif (file_exists($dbip)):
            $geodb = '--geoip-database='.$dbip;
        elseif (file_exists($maxmind)):
            $geodb = '--geoip-database='.$maxmind;
        else:
            $geodb = '';
        endif;

        $goaccess = shell_exec("/usr/local/bin/goaccess -a -o html --config-file=/dashboard/goaccess.conf ".$geodb);
        $goaccess = str_replace("<title>Server&nbsp;Statistics", "<title>SWAG&nbsp;Dashboard", $goaccess);
        $goaccess = str_replace("<h1 class='h-dashboard'>", "<h1>", $goaccess);
        $goaccess = str_replace("<i class='fa fa-tachometer'></i>", "<img src='/icon.svg' width='32' height='32'>&nbsp;SWAG&nbsp;", $goaccess);
        $goaccess = preg_replace("/(<link rel='icon' )(.*?)(>)/", "<link rel='icon' type='image/svg+xml' href='/icon.svg'>", $goaccess);
        return $goaccess;
    }
    
    function GetCertificate() {
        $certdate = shell_exec("openssl x509 -in /config/keys/letsencrypt/fullchain.pem -noout -enddate | awk -F '=' '{print \$NF}'");
        $certtime = strtotime($certdate);
        $certdateshort = date('Y-m-d', $certtime );
        if (time() < $certtime) {
            $ssl = '<i class="fas fa-lock"></i> SSL certificate valid until '.$certdateshort;
        } else {
            $ssl = '<i class="fas fa-exclamation-circle" title="Check the container logs for more details"></i> SSL certificate expired on '.$certdateshort;
        }
        return <<<HTML
            <div class="pull-right status-div">
                <h4>
                    <span class="label label-info" style="display:block">
                        {$ssl}
                    </span>
                </h4>
            </div>
        HTML;
    }
    
    $goaccess = GetGoaccess();
    $status = GetHeader() 
            . GetProxies() 
            . GetF2B() 
            . GetF2B('/var/lib/fail2ban/fail2ban.sqlite3')  // add a mounted f2bdb from the host in read only
            . GetTemplates() 
            . GetAnnouncements() 
            . GetLinks() 
            . "<div class='wrap-general'>";
    $page = str_replace("<div class='wrap-general'>", $status, $goaccess);
    $ssl = GetCertificate() . "<div class='pull-right hide'>";
    $page = str_replace("<div class='pull-right'>", $ssl, $page);
    echo $page;
?>
