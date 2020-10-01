
--function functionReturned(address, value)
--  emu.breakExecution()
--  if address ~= 0x0000 then
--   emu.log(string.format("Error: Break on wrong address 0x%4X", address))
--    return
--  end
function functionReturned()  
  emu.breakExecution()
  r1 = emu.getLabelAddress("R1")
  result = emu.read(r1, cpu, true)
  emu.log(result)
end


--emu.breakExecution()


state = emu.getState()
state.cpu.status = 0
state.cpu.irqFlag = 0
state.cpu.nmiFlag = 0
state.cpu.cycleCount = 0
--Clear the stack
--for s = 0x100, 0x1FF, 1 do
--  emu.write(s, 0, cpuDebug)
--end


--Set the stack pointer to return to the reset vector
--emu.writeWord(0x1FD, 0x8000 - 1,cpu) 
--state.cpu.sp = 0xFC



increment16_acc = emu.getLabelAddress("increment16_acc") 
state.cpu.pc = increment16_acc - 2
--emu.log(string.format("0x%4X", state.cpu.pc))


--Load values into argument registers
--r1 = emu.getLabelAddress("R1")
--r2 = emu.getLabelAddress("R2")
--emu.write(r1,0x0a, cpuDebug) 
--emu.write(r2,0xa0, cpuDebug)

emu.addEventCallback(functionReturned, reset)
--emu.addMemoryCallback(functionReturned, cpuExec ,0x1FF)
emu.setState(state)
--emu.execute(10, cpuInstructions)
--emu.resume()
