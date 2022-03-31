; MagicDespawn by spooonsss
; Despawns the oldest magikoopa magic (or sprites they turn into)
; (Magics spawned at room load are not considered)
; Install as UberASM, but be aware it includes hijacks

!max_magics = 3
assert !max_magics >= 3
!freeram = $0F5E ; at least !max_magics bytes, cannot include bank
!bank1_empty = $01FFFC ; at least 4 bytes

; end of configuration

; !freeram is list of sprite slots, oldest first. Empty slots are $FF

pushpc
org $01BF2D
LDA.b #$01 ; magikoopa spawns magic in init state instead of #$08

org $0181BD
dw magic_init_hijack ; overwrite magic init pointer

org !bank1_empty ; empty space in bank 1
magic_init_hijack:
JML magic_init
pullpc

init:
; n.b. this runs after sprites that spawn on room load are initialized
LDX #!max_magics-1
LDA #$FF
.loop
STA !freeram,x
DEX
BPL .loop

RTL

main:

; for debugging, make mario invincible:
LDA #1
STA $71

; first, look for dead sprites and remove from !freeram list
LDX #!max_magics-1
.dead_loop:
LDA !freeram,x
BMI .dead_loop_continue
TAY
LDA !sprite_status,y
BNE .dead_loop_continue
; sprite in slot y is dead - remove from list
CPX #!max_magics-1 ; skip loop if it the last in the list
BEQ .end_shift_loop

TXY
.shift_loop
LDA !freeram+1,y
STA !freeram,y
INY
CPY #!max_magics-1
BNE .shift_loop

.end_shift_loop
LDA #$FF
STA !freeram+!max_magics-1


.dead_loop_continue
DEX
BPL .dead_loop


; now see how many sprite slots are available
LDY #0
LDX #!sprite_slots-($0C-$09) ; magikoopa looks for empty slots in #$09 to #0 (lorom)
.count_living
LDA !sprite_status,x
BEQ +
INY
+
DEX
BPL .count_living


CPY #!sprite_slots-($0C-$09)+1
BNE despawn_first_ret
LDA !freeram
BMI despawn_first_ret
; at this point, there are no available sprite slots where magikoopa looks. despawn the oldest one

despawn_first:
; despawn the first sprite
LDX !freeram
STZ !sprite_status,x

LDY.b #$03
.smoke_loop:
LDA.w $17C0|!addr,Y
BEQ .glitter
DEY
BPL .smoke_loop
BRA .shift_list

.glitter
LDA #$05
STA $17C0|!addr,Y
LDA !sprite_x_low,x
STA $17C8|!addr,Y
LDA !sprite_y_low,x
STA $17C4|!addr,Y
LDA #$10
STA $17CC|!addr,Y

.shift_list
; shift the list left
LDY #0
.shift_loop2
LDA !freeram+1,y
STA !freeram,y
INY
CPY #!max_magics-1
BNE .shift_loop2

.end_shift_loop2
LDA #$FF
STA !freeram+!max_magics-1


.ret
RTL

magic_init:

; add bank to return address
PLY
PLX
LDA #1|!bank8
PHA
PHX
PHY


; store our sprite slot to the end of the !freeram list
LDX #0
.add_loop
LDA !freeram,x
BPL .add_loop_continue ; empty slots are $FF

LDA $15E9
STA !freeram,x
BRA .ret

.add_loop_continue
INX
CPX #!max_magics
BNE .add_loop

; no empty slots
JSL despawn_first
LDA $15E9
STA !freeram+!max_magics-1

.ret:
LDX $15E9
RTL
