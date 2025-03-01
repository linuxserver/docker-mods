<h2>Proxies</h2>
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
    <?php
        $output = shell_exec("if test -f /lsiopy/bin/python3; then /lsiopy/bin/python3 /dashboard/swag-proxies.py; else python3 /dashboard/swag-proxies.py; fi");
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
        echo $status;
    ?>
    </tbody>
</table>
<br/>