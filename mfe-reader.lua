local monitor = peripheral.find("monitor")
local mfe = peripheral.find("mfe")

if not monitor then
    error("No monitor found.")
end

if not mfe then
    error("No MFE peripheral found.")
end

monitor.setTextScale(2)

while true do
    local energy = mfe.getEnergyStored()
    local maxEnergy = mfe.getMaxEnergyStored()

    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.write("IC2 MFE")

    monitor.setCursorPos(1, 3)
    monitor.write(string.format("%,d / %,d EU", energy, maxEnergy))

    monitor.setCursorPos(1, 5)
    monitor.write(string.format("%.1f%%", energy / maxEnergy * 100))

    sleep(0.5)
end
