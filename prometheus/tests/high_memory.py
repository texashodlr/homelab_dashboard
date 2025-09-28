import time
import gc
print("Starting memory allocation...")

# Use a list to store large strings to consume memory
memory_list = []
i = 0
while True:
    try:
        # Create a large string and append it to the list
        large_string = ' ' * (10 * 10**6)  # 10 MB string
        memory_list.append(large_string)
        i += 1
        if i % 100 == 0:  # Print status every 10 allocations
            print(f"Allocated {i} chunks of 10 MB, total: {len(memory_list) * 10} MB")
            time.sleep(10)
    except MemoryError:
        print(f"Memory allocation failed after {i} chunks. Maximum reached.")
        break

print("Forcing garbage collection...")
gc.collect()