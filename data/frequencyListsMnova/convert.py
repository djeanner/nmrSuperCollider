 # echo "	peak.delta(), "\t", peak.intensity, "\t", peak.width() * freq, "\t", peak.integralInPts(spec), "
import os
import sys

def process_file(filename, min_second_column_value, larmor):
    # Open the original file
    with open(filename, 'r') as f:
        lines = f.readlines()

    # Process the lines
    first_column_values = []
    second_column_values = []
    for line in lines:
        # Split the line into columns
        columns = line.strip().split()
        
        # Check if there are at least two columns
        if len(columns) >= 2:
            try:
                # Append the first column value multiplied by larmor
                first_column_values.append(float(columns[0]) * larmor)
                # Append the second column value
                second_column_values.append(float(columns[1]))
            except ValueError:
                print(f"Skipping line: {line.strip()} (non-numeric value in first or second column)")

    # Check if there are any lines left after reading
    if not second_column_values:
        print(f"No lines left in file {filename} after reading.")
        return

    # Find the maximum value in the second column
    max_second_column_value = max(second_column_values)

    # Rescale the second column values
    rescaled_second_column_values = [value / max_second_column_value * 100 for value in second_column_values]

    # Filter out lines based on the minimum second column value after normalization
    filtered_first_column_values = []
    filtered_rescaled_second_column_values = []
    for first_column_value, rescaled_second_column_value in zip(first_column_values, rescaled_second_column_values):
        if rescaled_second_column_value >= min_second_column_value:
            filtered_first_column_values.append(first_column_value)
            filtered_rescaled_second_column_values.append(rescaled_second_column_value)
    # Check if there are any lines left after filtering
    if not filtered_rescaled_second_column_values:
        print(f"No lines left in file {filename} after filtering by minimum second column value {min_second_column_value}.")
        return

    # Create the new lines
    new_lines = [f"{first_column_value} {rescaled_second_column_value}\n" 
                 for first_column_value, rescaled_second_column_value 
                 in zip(filtered_first_column_values, filtered_rescaled_second_column_values)]

    # Create the new filename
    new_filename = filename.replace('.txt', '.list')

    # Write the new lines to the new file
    with open(new_filename, 'w') as f:
        f.writelines(new_lines)

    print(f"Processed file: {filename}")

def main():
    # Set default values
    larmor = 500.0
    min_second_column_value = 0.0

    # Check if command-line arguments were provided
    if len(sys.argv) > 1:
        try:
            larmor = float(sys.argv[1])
        except ValueError:
            print("Error: Larmor value should be a number.")
            return
    if len(sys.argv) > 2:
        try:
            min_second_column_value = float(sys.argv[2])
        except ValueError:
            print("Error: Minimum second column value should be a number.")
            return

    # Get all.txt files in the current directory
    for filename in os.listdir():
        if filename.endswith(".txt"):
            process_file(filename, min_second_column_value, larmor)

if __name__ == "__main__":
    main()
