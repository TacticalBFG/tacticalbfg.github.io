<?php
  if (ISSET($_GET["abc"])) {
  echo "hi";
  }
?>

<html>
<body>
<h2>hi</h2>

<form action="helicity.php" method="get">
  <input name="abc" type="text" />
  <input type="submit" />
</form>
</body>
</html>
