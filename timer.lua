return function()
	local time = {
		tasks = {}
	}
	
	function time:update(dt)
		for i, task in pairs(self.tasks) do
			task.timer = task.timer + dt

			if task.t == "every" then
				if task.timer > task.time then
					task.timer = 0
					task.callback()
				end
			elseif task.t == "after" then
				if task.timer > task.time then
					task.callback()
					table.remove(self.tasks, key)
				end
			end
		end
	end

	function time:every(time, callback)
		table.insert(self.tasks, {
			t = "every",
			timer = 0,
			time = time,
			callback = callback
		})

		return #self.tasks
	end
	
	function time:after(time, callback)
		table.insert(self.tasks, {
			t = "after",
			timer = 0,
			time = time,
			callback = callback
		})

		return #self.tasks
	end
	
	function time:cancel(index)
		table.remove(self.tasks, index)
	end

	function time:changeTime(id, time)
		self.tasks[id].time = time
	end

	return time
end
