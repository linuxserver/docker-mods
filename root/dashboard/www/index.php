<?php
    function GetStatus() {
        $output = shell_exec("python3 /dashboard/swag-status.py");
        $results = json_decode($output);
        $status = "";
        $index = 0;
        foreach($results as $result => $data){
            $tr_class = ($index % 2 == 0) ? 'shaded' : '';
            $status .= '<tr class="'.$tr_class.'"><td><span class="status-text">'.$result.'</span></td><td class="align-td">';
            if ($data->status == 1) {
                $status .= '<span class="green-circle circle-empty"></span>';
            } else {
                $status .= '<span class="red-circle"></span>';
            }
            $status .= '</td><td class="align-td">';
            if (!empty($data->locations)) {
                $locations = $data->locations;
                $location = implode(",", $locations);
                $status .= '<span class="green-circle circle-empty"></span></td><td><span class="status-text">'.$location.'</span></td>';
            } else {
                $status .= '<span class="red-circle"></span></td><td></td>';
            }
            $status .= '</tr>';
            $index++;
        }
        return <<<HTML
            <style type="text/css">
                .status-div {
                    display: inline-block;
                }
                .status-text {
                    font-size: 15px;
                }
                td {
                    padding: 6px;
                    text-align: center;
                }
                .align-td {
                    text-align: center;
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
            <h1>Welcome to your <a target="_blank" href="https://github.com/linuxserver/docker-swag">SWAG</a> instance</h1>
            <h4>A webserver and reverse proxy solution brought to you by <a target="_blank" href="https://www.linuxserver.io/">linuxserver.io</a> with php support and a built-in Certbot client.</h4>
            <h4>We have an article on how to use swag here: <a target="_blank" href="https://docs.linuxserver.io/general/swag">docs.linuxserver.io</a></h4>
            <h4>For help and support, please visit: <a target="_blank" href="https://www.linuxserver.io/support">linuxserver.io/support</a></h4>
            <div class="wrap-panel status-div">
                <div>
                    <table class="table-hover">
                        <col>
                        <col>
                        <col>
                        <col>
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
            <div class="wrap-general">
        HTML;
    }
    $access = shell_exec("cat /config/log/nginx/access.log | goaccess -a -o html --html-prefs='{\"theme\":\"darkGray\"}' --log-format COMBINED --geoip-database=/config/geoip2db/GeoLite2-City.mmdb -");
    $status = GetStatus();
    echo str_replace("<div class='wrap-general'>", $status, $access);
?>
