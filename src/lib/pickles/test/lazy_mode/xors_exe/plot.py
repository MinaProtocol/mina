import matplotlib.pyplot as plt
import pandas as pd

# Read the log files
lazy_log = pd.read_csv('lazy-565065.txt', delim_whitespace=True, skiprows=1,
                       names=['Time', 'CPU', 'Real_Mem', 'Virtual_Mem'])
eager_log = pd.read_csv('eager-566411.txt', delim_whitespace=True, skiprows=1,
                        names=['Time', 'CPU', 'Real_Mem', 'Virtual_Mem'])

# Plot CPU usage
plt.figure(figsize=(10, 5))
plt.plot(lazy_log['Time'], lazy_log['CPU'], label='Lazy Mode CPU')
plt.plot(eager_log['Time'], eager_log['CPU'], label='Eager Mode CPU')
plt.xlabel('Time (s)')
plt.ylabel('CPU Usage (%)')
plt.title('CPU Usage Comparison')
plt.legend()
plt.grid(True)
plt.savefig('cpu_comparison.png')

# Plot Memory usage
plt.figure(figsize=(10, 5))
plt.plot(lazy_log['Time'], lazy_log['Real_Mem'], label='Lazy Mode Memory')
plt.plot(eager_log['Time'], eager_log['Real_Mem'], label='Eager Mode Memory')
plt.xlabel('Time (s)')
plt.ylabel('Memory Usage (MB)')
plt.title('Memory Usage Comparison')
plt.legend()
plt.grid(True)
plt.savefig('memory_comparison.png')