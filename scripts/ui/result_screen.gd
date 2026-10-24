extends Control


func show_result(victory: bool, seconds: float, kills: int, level: int) -> void:
	$Center/Content/Heading.text = "DAWN HAS RETURNED" if victory else "THE LIGHT HAS FADED"
	$Center/Content/Hint.text = "Your light outlasted the winter." if victory else "The winter claimed another keeper."
	var time: int = int(seconds)
	$Center/Content/Stats.text = "TIME SURVIVED  %02d:%02d\nSHADOWS BANISHED  %d\nFINAL LEVEL  %d" % [floori(float(time) / 60.0), time % 60, kills, level]
	$Center/Content/Retry.text = "Play Again"
	show()
	$Center/Content/Retry.grab_focus()
