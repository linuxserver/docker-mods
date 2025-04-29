<?php
    function GetHeader() {
        return <<<HTML
            <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.7.1/jquery.min.js"></script>
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
                .fa-exclamation-circle,.fa-check-circle, .fa-info-circle, .fa-edit, .fa-lock, .fa-lock-open {
                    font-size:20px;
                    padding: 2px;
                }
                .fa-lock-open {
                    color: gray;
                    padding-left: 7px;
                    cursor: help;
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
        $output = shell_exec("if test -f /lsiopy/bin/python3; then /lsiopy/bin/python3 /dashboard/swag-proxies.py fast; else python3 /dashboard/swag-proxies.py fast; fi");
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
                $status .= '<i class="fas fa-check-circle"></i></td><td class="align-td">';
                $auths = implode(PHP_EOL, $data->auths);
                if ($data->auth_status == 1) {
                    $status .= '<i class="fas fa-lock" title="'.$auths.'"></i>';
                } else {
                    $status .= '<i class="fas fa-lock-open"  title="'.$auths.'"></i>';
                }
                $status .= '</td><td class="left-text"><span class="status-text">'.$location.'</span></td>';
            } else {
                $error = 'Unable to locate the proxy config for '.$result.', it must use the following structure:'.PHP_EOL;
                $error .= '&#09;set $upstream_app <container/address>;'.PHP_EOL;
                $error .= '&#09;set $upstream_port <port>;'.PHP_EOL;
                $error .= '&#09;set $upstream_proto <protocol>;'.PHP_EOL;
                $error .= '&#09;proxy_pass $upstream_proto://$upstream_app:$upstream_port;'.PHP_EOL;
                $status .= '<i class="fas fa-exclamation-circle" title="'.$error.'"></i></td><td></td><td></td>';
            }
            $status .= '</tr>';
            $index++;
        }
        return <<<HTML
            <div class="wrap-panel status-div">
                <div id="proxiesTable">
                    <script>
                        $.ajax({
                            url : 'proxies.php',
                            type: 'GET',
                            success: function(data){
                                $('#proxiesTable').html(data);
                            }
                        });
                    </script>
                    <h2>Proxies</h2>
                    <h4>Scanning for unproxied containers ...</h4>
                    <table class="table-hover">
                        <thead>
                            <tr>
                                <td><h3>Application</h3></td>
                                <td><h3>Available</h3></td>
                                <td><h3>Proxied</h3></td>
                                <td><h3>Auth</h3></td>
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

    function GetF2B() {
        $output = shell_exec("if test -f /lsiopy/bin/python3; then /lsiopy/bin/python3 /dashboard/swag-f2b.py; else python3 /dashboard/swag-f2b.py; fi");
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
            ".conf" => "https://github.com/linuxserver/docker-swag/blob/master/root/defaults/nginx/",
            "subdomain.conf" => "https://github.com/linuxserver/reverse-proxy-confs/blob/master/",
            "subfolder.conf" => "https://github.com/linuxserver/reverse-proxy-confs/blob/master/",
            "dashboard.subdomain.conf" => "https://github.com/linuxserver/docker-mods/blob/swag-dashboard/root/dashboard/",
            "nginx.conf" => "https://github.com/linuxserver/docker-baseimage-alpine-nginx/tree/master/root/defaults/nginx/",
            "ssl.conf" => "https://github.com/linuxserver/docker-baseimage-alpine-nginx/tree/master/root/defaults/nginx/",
            "default.conf" => "https://github.com/linuxserver/docker-swag/blob/master/root/defaults/nginx/site-confs/",
        );
        $output = shell_exec("/etc/s6-overlay/s6-rc.d/init-version-checks/run");

        foreach(explode(PHP_EOL, $output) as $line) {
            if(substr($line, 0, 1) === "*"){
                $tooltip .= str_replace("*", "", $line).PHP_EOL;
            } elseif(str_contains($line, "/config/")) {
                $tr_class = ($counter % 2 == 0) ? 'shaded' : '';
                $clean_line = htmlspecialchars($line);
                list($old_date, $new_date, $path) = explode(' │ ', $clean_line);
                $old_date = trim($old_date, '│ \n\r\t\v\x00');
                $new_date = trim($new_date, '│ \n\r\t\v\x00');
                $path = trim($path, '│ \n\r\t\v\x00');
                $files .= '<tr class="'.$tr_class.'">';
                $files .= '<td class="left-text"><span class="status-text">'.$old_date.'</span></td>';
                $files .= '<td class="left-text"><span class="status-text">'.$new_date.'</span></td>';
                $files .= '<td class="left-text"><span class="status-text">'.$path.'</span></td>';
                $file_name = substr($path, strrpos($path, '/') + 1);
                foreach($conf_locations as $key=>$value) {
                    if (strpos($file_name, $key) !== false) {
                        $link = $value.$file_name;
                    }
                }
                $files .= '<td><a href="'.$link.'.sample"><i class="fas fa-edit"></i></a></td></tr>';
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
                        <thead>
                            <tr>
                                <td><h3>Old Date</h3></td>
                                <td><h3>New Date</h3></td>
                                <td><h3>Path</h3></td>
                                <td><h3>Link</h3></td>
                            </tr>
                        </thead>
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
        $geodb = '';
        $dbip = '/config/geoip2db/dbip-country-lite.mmdb';
        $maxmind = '/config/geoip2db/GeoLite2-City.mmdb';
        if (file_exists($dbip) and file_exists($maxmind)):
            $geodb = (filemtime($dbip) > filemtime($maxmind)) ? '--geoip-database='.$dbip : '--geoip-database='.$maxmind;
        elseif (file_exists($dbip)):
            $geodb = '--geoip-database='.$dbip;
        elseif (file_exists($maxmind)):
            $geodb = '--geoip-database='.$maxmind;
        endif;

        $asndb = '';
        $asn = '/config/geoip2db/asn.mmdb';
        if (file_exists($asn)):
            $asndb = '--geoip-database='.$asn;
        endif;

        $access_log = file_exists("/dashboard/logs") ? "/dashboard/logs/*.log" : "/config/log/nginx/access.log";
        $goaccess = shell_exec("cat $access_log | /usr/bin/goaccess -a -o html --config-file=/dashboard/goaccess.conf $geodb $asndb -");
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
    
    function GetStats() {
        $output = shell_exec("if test -f /lsiopy/bin/python3; then /lsiopy/bin/python3 /dashboard/swag-f2b.py; else python3 /dashboard/swag-f2b.py; fi");
        $jails = json_decode($output, true);
        $banned = 0;
        foreach($jails as $jail){
            $banned = $banned + $jail["bans"];
        }

        $output = shell_exec("if test -f /lsiopy/bin/python3; then /lsiopy/bin/python3 /dashboard/swag-proxies.py fast; else python3 /dashboard/swag-proxies.py fast; fi");
        $results = json_decode($output);
        $proxied = 0;
        $auth = 0;
        foreach($results as $result => $data){
            if (!empty($data->locations)){
                $proxied++;
                if ($data->auth_status == 1) {
                    $auth++;
                }
            }
        }

        $output = shell_exec("/etc/s6-overlay/s6-rc.d/init-version-checks/run");
        $outdated = 0;
        foreach(explode(PHP_EOL, $output) as $line) {
            if(str_contains($line, "/config/")) {
                $outdated++;
            }
        }

        return array("proxied" => "$proxied", "auth" => "$auth", "outdated" => "$outdated", "banned" => "$banned");
    }

    $stats = (isset($_GET['stats']) && $_GET['stats'] == 'true') ? true : false;
    if($stats) {
        $page = GetStats();
        header("Content-Type: application/json");
        echo json_encode($page);
    } else {
        $goaccess = GetGoaccess();
        $status = GetHeader() . GetProxies() . GetF2B() . GetTemplates() . GetAnnouncements() . GetLinks() . "<div class='wrap-general'>";
        $page = str_replace("<div class='wrap-general'>", $status, $goaccess);
        $ssl = GetCertificate() . "<div class='pull-right hide'>";
        $page = str_replace("<div class='pull-right'>", $ssl, $page);
        echo $page;
    }
?>
