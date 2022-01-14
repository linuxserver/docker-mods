<?php
    function GetHeader() {
        return <<<HTML
            <style type="text/css">
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
                .green-circle {
                    padding: 2px 10px;
                    border-radius: 100%;
                    background-color: green;
                    border: 1px solid black;
                }
                .red-circle {
                    padding: 2px 10px;
                    border-radius: 50%;
                    background-color: red;
                    border: 1px solid black;
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
                $status .= '<span class="green-circle circle-empty"></span>';
            } else {
                $status .= '<span class="red-circle"></span>';
            }
            $status .= '</td><td>';
            if (!empty($data->locations)) {
                $locations = $data->locations;
                $location = implode(",", $locations);
                $status .= '<span class="green-circle circle-empty"></span></td><td class="left-text"><span class="status-text">'.$location.'</span></td>';
            } else {
                $status .= '<span class="red-circle"></span></td><td></td>';
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

    function GetF2B() {
        $output = exec("python3 /dashboard/swag-f2b.py");
        $jails = json_decode($output, true);
        $status = "";
        $index = 0;
        foreach($jails as $jail){
            $tr_class = ($index % 2 == 0) ? 'shaded' : '';
            $status .= '<tr class="'.$tr_class.'"><td class="left-text"><span class="status-text">'.$jail["name"].'</span></td>';
            $status .= '<td><span class="status-text">'.$jail["bans"].'</span></td>';
            $status .= '<td><span class="status-text" title="'.htmlspecialchars($jail["data"]).'">'.$jail["last_ban"].'</span></td></tr>';
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

    $geodb = file_exists('/config/geoip2db/GeoLite2-City.mmdb') ? '--geoip-database=/config/geoip2db/GeoLite2-City.mmdb' : '';
    $goaccess = shell_exec("goaccess -a -o html --config-file=/dashboard/goaccess.conf ".$geodb);
    $status = GetHeader() . GetProxies() . GetF2B() . GetAnnouncements() . GetLinks() . '<div class="wrap-general">';
    $page = str_replace("<div class='wrap-general'>", $status, $goaccess);
    $page = str_replace("<title>Server&nbsp;Statistics", "<title>SWAG&nbsp;Dashboard", $page);
    $page = str_replace("<h1 class='h-dashboard'>", "<h1>", $page);
    $page = str_replace("<i class='fa fa-tachometer'></i>", "<img src='/icon.svg' width='32' height='32'>&nbsp;SWAG&nbsp;", $page);
    $page = preg_replace("/(<link rel='icon' )(.*?)(>)/", "<link rel='icon' type='image/svg+xml' href='/icon.svg'>", $page);
    echo $page;
?>
