
ardour{
	["type"]    = "dsp",
	name        = "VAmpNL",
	category    = "Distortion",
	license     = "BSD",
	author      = "mqnc",
	description = [[Nonlinear distortion curve for simulating amps, to be inserted between two EQs, modeled according to "Block-oriented modeling of distortion audio effects using iterative minimization" by Felix Eichas, Stephan Möller, Udo Zölzer, implemented by Mirko Kunze]]
}

-- configure number of input and output channels
function dsp_ioconfig()
	return {{audio_in = 1, audio_out = 1}}
end

-- parameters that can be configured from Ardour
function dsp_params()
	return {
		{ ["type"] = "input", name = "pre-gain (g_pre)", min = -20, max = 20, default = 6, unit="dB"},
		{ ["type"] = "input", name = "side chain envelope LP freq (f_c)", min = 1, max = 100, default = 5, logarithmic = true, unit="Hz"},
		{ ["type"] = "input", name = "bias-gain (g_sc)", min = -20, max = 20, default = -6, unit="dB"},
		{ ["type"] = "input", name = "positive kink (k_p)", min = 0, max = 1, default = 0.2},
		{ ["type"] = "input", name = "negative kink (k_n)", min = 0, max = 1, default = 0.7},
		{ ["type"] = "input", name = "positive sharpness (g_p)", min = -20, max = 120, default = 3, unit="dB"},
		{ ["type"] = "input", name = "negative sharpness (g_n)", min = -20, max = 120, default = 30, unit="dB"},
		{ ["type"] = "input", name = "mix (alpha)", min = 0, max = 1, default = 0.85},
		{ ["type"] = "input", name = "post-gain (g_post)", min = -20, max = 20, default = -1, unit="dB"},
	}
end

-- store last control values for detecting changes
local ctrl_last = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0}

-- configuration parameters
local gpre
local gsc
local kp
local tanh_kp
local qp
local kn
local tanh_kn
local qn
local gp
local gn
local alpha
local gpost

-- parameters for envelope low pass
local dt -- sampling time
local a -- interpolation parameter (https://en.wikipedia.org/wiki/Low-pass_filter#Discrete-time_realization)
local LP_x_last = 0.0 -- memory

-- initialization
function dsp_init (rate)
	dt = 1.0/rate
	self:shmem():allocate(32)
	self:shmem():clear()
end

-- math.tanh does not work so we need our own tanh
function tanh(x)
	return 1.0-2.0/(math.exp(2.0*x)+1.0)
end

-- main processor
function dsp_run (ins, outs, n_samples)

	-- update control values
	local ctrl = CtrlPorts:array()
	local changed = false
	for i = 1, 9 do
		if ctrl[i] ~= ctrl_last[i] then
			ctrl_last[i] = ctrl[i]
			changed = true
		end
	end

	-- compute new parameters
	if changed then
		gpre = ARDOUR.DSP.dB_to_coefficient(ctrl[1])
		a = dt / (1.0/(6.2832*ctrl[2]) + dt)
		gsc = ARDOUR.DSP.dB_to_coefficient(ctrl[3])
		kp = ctrl[4]
		kn = ctrl[5]
		gp = ARDOUR.DSP.dB_to_coefficient(ctrl[6])
		gn = ARDOUR.DSP.dB_to_coefficient(ctrl[7])
		alpha = ctrl[8]
		gpost = ARDOUR.DSP.dB_to_coefficient(ctrl[9])

		tanh_kp = tanh(kp)
		qp = (tanh_kp*tanh_kp -1.0)/gp
		tanh_kn = tanh(kn)
		qn = (tanh_kn*tanh_kn -1.0)/gn

		-- trigger inline display redraw
		self:queue_draw()
	end

	-- copy input to output
	ARDOUR.DSP.copy_vector (outs[1], ins[1], n_samples)

	-- process output in place
	local u = outs[1]:array()
	for i=1, n_samples do

		local g_x = gpre*u[i]
		local LP_x = a*math.abs(g_x) + (1.0-a) * LP_x_last
		LP_x_last = LP_x
		local bias_x = g_x - gsc*LP_x
		local raw_y = 0

		if bias_x > kp then
			raw_y = tanh_kp - qp*tanh(gp*(bias_x-kp))
		elseif bias_x >= kn then
			raw_y = tanh(bias_x)
		else
			raw_y = -tanh_kn - qn*tanh(gn*(bias_x+kn))
		end

		u[i] = gpost * (alpha*raw_y + (1.0-alpha)*g_x)

	end

end

-- maps amplitude to inline display position
function scale(x, y, w, h)
	return math.floor((x/1.2+1.0)*0.5*(w-1) + 0.5), math.floor((1.0-y/1.2)*0.5*(h-1) + 0.5)
end

-- inline display render callback
function render_inline (ctx, w, max_h)

	-- all similar to the main processor except there is no side chain envelope bias

	local ctrl = CtrlPorts:array()
	local gpre = ARDOUR.DSP.dB_to_coefficient(ctrl[1])
	-- local a = dt / (1.0/(6.2832*ctrl[2]) + dt)
	local gsc = ARDOUR.DSP.dB_to_coefficient(ctrl[3])
	local kp = ctrl[4]
	local kn = ctrl[5]
	local gp = ARDOUR.DSP.dB_to_coefficient(ctrl[6])
	local gn = ARDOUR.DSP.dB_to_coefficient(ctrl[7])
	local alpha = ctrl[8]
	local gpost = ARDOUR.DSP.dB_to_coefficient(ctrl[9])

	local tanh_kp = tanh(kp)
	local qp = (tanh_kp*tanh_kp -1.0)/gp
	local tanh_kn = tanh(kn)
	local qn = (tanh_kn*tanh_kn -1.0)/gn


	local h = w
	if (h > max_h) then h = max_h end

	-- clear display
	ctx:rectangle (0, 0, w, h)
	ctx:set_source_rgba (0.2, 0.2, 0.2, 1.0)
	ctx:fill()

	-- draw grid
	ctx:set_source_rgba (0.5, 0.5, 0.5, 1.0)
	for i=-1,1 do
		ctx:move_to(scale( i,-1, w,h))
		ctx:line_to(scale( i, 1, w,h))
		ctx:stroke()

		ctx:move_to(scale(-1, i, w,h))
		ctx:line_to(scale( 1, i, w,h))
		ctx:stroke()
	end

	-- orange
	ctx:set_source_rgba (1.0, 0.5, 0.0, 1.0)

	local x=0
	local n=48

	for i=1, n do
		x = ((2.0*(i-1.0))/(n-1.0)-1.0)*1.2

		local g_x = gpre*x
		local raw_y = 0

		if g_x > kp then
			raw_y = tanh_kp - qp*tanh(gp*(g_x-kp))
		elseif g_x >= -kn then
			raw_y = tanh(g_x)
		else
			raw_y = -tanh_kn - qn*tanh(gn*(g_x+kn))
		end

		local y = gpost * (alpha*raw_y + (1.0-alpha)*g_x)

		if i==1 then
			ctx:move_to(scale(x, y, w, h))
		else
			ctx:line_to(scale(x, y, w, h))
		end
	end

	-- draw
	ctx:stroke()

	return {w, h}
end
