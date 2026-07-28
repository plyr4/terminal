if [[ "$TERM_PROGRAM" == "ghostty" ]]; then
	# Shader roll counter. Exactly one roll segment per accepted keypress.
	#
	# Ghostty resets iTimeCursorChange and iPreviousCursorColor on ANY cursor
	# change, including plain cursor movement (see updateCustomShaderUniforms-
	# ForFrame in src/renderer/generic.zig). That makes it impossible for the
	# shader to time a roll on its own: moving the cursor mid-roll wipes the
	# previous color and restarts the clock. So we step the counter through the
	# roll here instead, and the shader maps counter -> rotation directly with
	# no timing uniforms at all.
	zmodload -i zsh/datetime
	zmodload -i zsh/zselect

	# Steps per roll segment. Must match ROLL_STEPS in shaders/shader.glsl,
	# and must divide 512 evenly so the 9-bit counter wraps on a segment edge.
	typeset -gi _GC_STEPS=8
	# Delay between steps, in 1/100s (zselect granularity). Measures out closer
	# to 12ms per step in practice, so a roll takes ~0.1s.
	typeset -gi _GC_STEP_CS=1
	# Cooldown must cover a whole roll, else a keypress could overlap one.
	typeset -gF _GC_ROLL_DURATION=0.12
	typeset -gF _GC_NEXT_ALLOWED=0
	typeset -gi _GC_COUNTER=0

	function _gc_emit_counter() {
		local counter=$(( $1 % 512 ))
		local high=$(( counter / 256 ))
		local hi=$(( (counter % 256) / 16 ))
		local lo=$(( counter % 16 ))
		local checksum=$(( (hi + lo * 3 + high * 5 + 7) % 16 ))
		printf '\033]12;#%02x%02x%02x\a' \
			$(( 0xE0 + hi )) \
			$(( 0x70 + lo )) \
			$(( 0xA0 + high * 16 + checksum )) \
			> "$TTY" 2>/dev/null
	}

	# Walk the counter through one 90-degree roll, one step per frame-ish.
	# Runs detached so it never blocks the line editor.
	function _gc_roll() {
		local -i start=$1 i
		for (( i = 1; i <= _GC_STEPS; i++ )); do
			zselect -t $_GC_STEP_CS
			_gc_emit_counter $(( (start + i) % 512 ))
		done
	}

	function _gc_self_insert() {
		local -F now=$EPOCHREALTIME
		# Keystrokes arriving mid-roll are ignored outright.
		if (( now >= _GC_NEXT_ALLOWED )); then
			(( _GC_NEXT_ALLOWED = now + _GC_ROLL_DURATION ))
			local -i start=$_GC_COUNTER
			(( _GC_COUNTER = (_GC_COUNTER + _GC_STEPS) % 512 ))
			_gc_roll $start &!
		fi
		zle .self-insert "$@"
	}

	zle -N self-insert _gc_self_insert

	# Prime the shader once per shell so it has a valid signal to decode.
	_gc_emit_counter $_GC_COUNTER
fi
