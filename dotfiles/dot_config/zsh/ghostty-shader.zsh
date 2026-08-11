if [[ "$TERM_PROGRAM" == "ghostty" ]]; then
	zmodload -i zsh/datetime
	zmodload -i zsh/zselect

	typeset -gi _GC_STEPS=8
	typeset -gi _GC_WRAP_SLOTS=48
	typeset -gi _GC_STEP_CS=1
	typeset -gF _GC_ROLL_DURATION=0.12
	typeset -gF _GC_NEXT_ALLOWED=0
	typeset -gi _GC_COUNTER_MOD=$(( _GC_WRAP_SLOTS * _GC_STEPS ))
	typeset -gi _GC_COUNTER=0
	typeset -gi _GC_ENABLED=1
	typeset -gi _GC_GEN=0

	function _gc_emit_counter() {
		(( _GC_ENABLED )) || return 0
		local counter=$(( $1 % _GC_COUNTER_MOD ))
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

	function _gc_roll() {
		local -i start=$1 gen=$2 i
		for (( i = 1; i <= _GC_STEPS; i++ )); do
			(( gen == _GC_GEN )) || break
			zselect -t $_GC_STEP_CS
			(( gen == _GC_GEN )) || break
			_gc_emit_counter $(( (start + i) % _GC_COUNTER_MOD ))
		done
	}

	function _gc_roll_reverse() {
		local -i start=$1 gen=$2 i
		for (( i = 1; i <= _GC_STEPS; i++ )); do
			(( gen == _GC_GEN )) || break
			zselect -t $_GC_STEP_CS
			(( gen == _GC_GEN )) || break
			_gc_emit_counter $(( (start - i + _GC_COUNTER_MOD) % _GC_COUNTER_MOD ))
		done
	}

	function _gc_self_insert() {
		local -F now=$EPOCHREALTIME
		if (( now >= _GC_NEXT_ALLOWED )); then
			(( _GC_NEXT_ALLOWED = now + _GC_ROLL_DURATION ))
			local -i start=$_GC_COUNTER
			local -i gen=$_GC_GEN
			(( _GC_COUNTER = (_GC_COUNTER + _GC_STEPS) % _GC_COUNTER_MOD ))
			_gc_roll $start $gen &!
		fi
		zle .self-insert "$@"
	}

	function _gc_backspace() {
		local -F now=$EPOCHREALTIME
		if (( now >= _GC_NEXT_ALLOWED )); then
			(( _GC_NEXT_ALLOWED = now + _GC_ROLL_DURATION ))
			local -i start=$_GC_COUNTER
			local -i gen=$_GC_GEN
			(( _GC_COUNTER = (_GC_COUNTER - _GC_STEPS + _GC_COUNTER_MOD) % _GC_COUNTER_MOD ))
			_gc_roll_reverse $start $gen &!
		fi
		zle .backward-delete-char "$@"
	}

	function _gc_enable() {
		(( _GC_ENABLED = 1 ))
		(( _GC_GEN++ ))
		zle -N self-insert _gc_self_insert
		zle -N backward-delete-char _gc_backspace
		_gc_emit_counter $_GC_COUNTER
	}

	function _gc_disable() {
		(( _GC_ENABLED = 0 ))
		(( _GC_GEN++ ))
		zle -A .self-insert self-insert
		zle -A .backward-delete-char backward-delete-char
		printf '\033]112\a' > "$TTY" 2>/dev/null
	}

	function _gc_toggle() {
		if (( _GC_ENABLED )); then
			_gc_disable
		else
			_gc_enable
		fi
	}

	function toggle-shader() {
		_gc_toggle
	}

	zle -N self-insert _gc_self_insert
	zle -N backward-delete-char _gc_backspace

	_gc_emit_counter $_GC_COUNTER
fi
