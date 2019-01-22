BEGIN{
	PIC_CYCLE_RATE = 4000000
	SAMPLE_MULTIPLIER = 1
	SAMPLE_RATE = 1

	HEADER = \
"stimulus asynchronous_stimulus\n\
\n\
# The initial state AND the state the stimulus is when\n\
# it rolls over\n\
\n\
initial_state 1\n\
start_cycle 0\n\
\n\
# the asynchronous stimulus will roll over in ’period’\n\
# cycles. Delete this line if you don’t want a roll over.\n\
\n\
period 1000000\n\
\n\
{"

	FOOTER = \
"}\n\
\n\
# Give the stimulus a name:\n\
name IR_data\n\
\n\
end"

	print HEADER
}
/Rate:/ { SAMPLE_RATE = $2; SAMPLE_MULTIPLIER = PIC_CYCLE_RATE / SAMPLE_RATE; FS = "@" }
/([0-9]+)@/ { print ($2 * SAMPLE_MULTIPLIER) ", " ($1 + 0) "," }
END{ print FOOTER }
