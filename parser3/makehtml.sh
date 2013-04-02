#!/bin/bash
outputhtml () {
cat <<EOF
<!DOCTYPE html>
<html style="padding:0; margin:0; height:100%">
  <body style="padding:0; margin:0; height:99%">
    <table style="border:0; padding:0; margin:0; height:100%; width:99%">
      <tr style="border:0; padding:0; margin:0">
        <td style="border:0; padding:0; margin:0">
EOF
if [ "$2" == full ] 
then cat $1_header.html
fi
cat <<EOF | sed s/NAME/"$1"/g
<form action="cgi-bin/NAME.cgi#end" method="GET" target="my_iframe">
 <textarea name="i" cols=40 rows=2 onkeydown="if (event.keyCode == 13) { this.form.submit(); return false; }">Gp|-p</textarea>
EOF
if [ "$1" == "unify" ] 
then #cat <<EOF
#<br/><textarea name="exclude" cols=40 rows=2 onkeydown="if (event.keyCode == 13) { this.form.submit(); return false; }">CTL BCTLOLD BCTLNEW BCTLHUE BPATHUE</textarea>
echo '<br/>'
for s in CTL BCTLOLD BCTLNEW BCTLHUE BPATHUE
do
 echo '<input type="checkbox" name="solver" value="'$s'"/> '$s '&nbsp; '
done
for s in mlsolver BPATH
do
 echo '<input type="checkbox" name="solver" value="'$s'" checked/> '$s '&nbsp; '
done
echo '<br/><input type="checkbox" name="simplify" value="y" checked/>' simplify '<br/>'
#EOF
fi
cat <<EOF
 <input type="submit" value="Go">
</form>

        </td>
      </tr>
      <tr style="border:0; padding:0; margin:0">
        <td style="border:0; padding:0; margin:0; height:100%">
<iframe 
	name="my_iframe"
        id="m"
        onload="document.getElementById('m').contentWindow.scrollTo(0,99999);"
	style="width:100%; height:100%;"
</iframe>
        </td>
      </tr>
    </table>
  </body>
</html>
EOF
}

outputhtml $1 full > $2.html
outputhtml $1 > $2_plain.html