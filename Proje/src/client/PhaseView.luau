local PhaseView = {}
PhaseView.__index = PhaseView

function PhaseView.new(refs)
	return setmetatable({ refs = refs, token = 0 }, PhaseView)
end

function PhaseView:show(main, extra)
	self.token += 1
	self.refs.asama_ana.Text = main
	self.refs.asama_ek.Text = extra or ""
	self.refs.asama_ekran.Enabled = true
end

-- compute() her 0.25 sn'de (ana, ek) metnini dondurur; baska bir show/ticker/hide gelince durur.
function PhaseView:ticker(compute)
	self:show(compute())
	local token = self.token
	task.spawn(function()
		while self.token == token do
			local main, extra = compute()
			self.refs.asama_ana.Text = main
			self.refs.asama_ek.Text = extra or ""
			task.wait(0.25)
		end
	end)
end

function PhaseView:hide()
	self.token += 1
	self.refs.asama_ekran.Enabled = false
end

return PhaseView
