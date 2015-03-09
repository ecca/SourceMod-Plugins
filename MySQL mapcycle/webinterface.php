<?php
$db = new mysqli("host", "username", "password", "database");
$table = "mapcycle";


if (mysqli_connect_errno())
{
    die("Couldn't establish a connection successfully");
}

if(!mysqli_num_rows($db->query("SHOW TABLES LIKE '".$table."'")))
{
	if($db->query("CREATE TABLE IF NOT EXISTS `".$table."` (`mapname` varchar(64) NOT NULL default '')"))
	{
		printf("Tables weren't found so i created them</br>");
	}
	else
	{
		printf("Couldn't create the tables!</br>");
	}
}

$rad = 0;

if(isset($_POST['submit']))
{
	$mapnames = $_REQUEST['maps'];

	foreach(explode("\n", $mapnames) as $maps)
	{
		$maps = preg_replace('/\s+/', '', $maps);
		
		$rad++;
		
		$db->query("INSERT INTO ".$table." (mapname) VALUES ('$maps')");
	}
	
	printf("Inserted %d maps", $rad);
}
?>
One map per row, be sure to remove spaces!
<form method="post" action="">
<textarea rows="30%" cols="100%" name="maps">
<?php
$querystring = $db->query("SELECT * FROM ".$table."");

while ($row = $querystring->fetch_assoc())
{
	printf("%s\n", $row['mapname']);
}

$querystring->close();
?>
</textarea></br>
<input type="submit" name="submit" value="submit">
</form>

<?php
$db->close();
?>