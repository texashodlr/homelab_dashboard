import multiprocessing
import time

def infinite_loop():
    print(f"Process {multiprocessing.current_process().pid} starting...")
    while True:
        pass

if __name__ == "__main__":
    num_cores = multiprocessing.cpu_count()
    print(f"Detected {num_cores} CPU cores")
    print("Starting a process for each core to maximize CPU utilization...")

    processes = []
    try:
        for i in range(num_cores):
            process = multiprocessing.Process(target=infinite_loop)
            process.start()
            processes.append(process)
        while True:
            time.sleep(10)
    
    except KeyboardInterrupt:
        print("\nCaught KB interrupt. Terminating process...")
        for process in processes:
            process.terminate()
            process.join()
        print("All Processes terminated.")