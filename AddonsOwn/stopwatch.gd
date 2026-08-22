class_name Stopwatch

var start_time: int = 0
var stop_time: int = 0
var running: bool = false
var description: String
var detailed: bool
var counter: int = 0

func _init(descr: String = "Time taken: ", start_immediately: bool = true, details: bool = false) -> void:
	description = descr
	detailed = details
	if start_immediately:
		start()


func start(descr: String = ""):
	running = true
	stop_time = 0
	start_time = Time.get_ticks_msec()
	if descr != "":
		description = descr
	if detailed:
		print(" --- Starting stopwatch at: %d ---" % [start_time] )


func stop():
	if running:
		stop_time = Time.get_ticks_msec()
		var elapsed = stop_time - start_time
		if detailed:
			var minutes = elapsed/60000
			var seconds = elapsed/1000
			var miliseconds = elapsed-seconds*1000
			if counter > 0:
				print(" --- Stopping stopwatch at: %d ---" % [stop_time] )
				print(description + "%02dm:%02ds:%03dms total | %dms | %d times | %dms average time" % [minutes, seconds, miliseconds, elapsed, counter, elapsed/counter])
			else:
				print(" --- Stopping stopwatch at: %d ---" % [stop_time] )
				print(description + "%02dm:%02ds:%03dms | %dms" % [minutes, seconds, miliseconds, elapsed])
		else:
			if counter > 0:
				print(description + "%dms total | %d times | %dms average time" % [elapsed, counter, elapsed/counter])
			else:
				print(description + "%dms" % [elapsed])
		running = false
	else:
		print("WARNING: requested stopwatch stop(), but not timing anything.")


func count():
	counter += 1
