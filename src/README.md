# Read Frequencies and Amplitudes from File

This project demonstrates how to dynamically read frequencies and amplitudes from a text file and play them using [SuperCollider](https://supercollider.github.io/). The code dynamically updates the playback every second based on changes in the file.

## Features

- Dynamically reads frequencies and amplitudes from a text file (`list1.txt`).
- Plays the sounds using SuperCollider's `Synth` objects.
- Automatically updates playback when the file content changes.

---

## Installation

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/yourusername/read-frequencies-amplitudes.git
   cd read-frequencies-amplitudes
   ```

2. **Install SuperCollider**:
   If you don’t already have SuperCollider installed, download it from the [SuperCollider website](https://supercollider.github.io/).

3. **Run the Demo**:
   - Open `src/readFrequenciesAmplitudesFromFile.scd` in SuperCollider.
   - Ensure the `data/list1.txt` file contains frequency-amplitude pairs (see the format below).
   - Fix the path of the source file at line 5 of the `.scd` file.
   - In SuperCollider start a sever in the "Server" tab, select "Boot server".

---

## Usage

### File Format

The `list1.txt` file should contain frequency and amplitude pairs, one per line, separated by a space. For example:
```
440 0.5
880 0.3
220 0.6
```

### Running the Script

1. Start the SuperCollider server by executing `s.boot` in the SuperCollider IDE.
2. Run the script `src/readFrequenciesAmplitudesFromFile.scd` in SuperCollider.
3. Modify the `list1.txt` file to change the frequencies and amplitudes. Updates will take effect within one second.

---

## Project Structure

```plaintext
.
├── README.md                   # Project documentation
├── data/
│   └── list1.txt               # Demo file with frequencies and amplitudes
├── src/
│   └── readFrequenciesAmplitudesFromFile.scd  # SuperCollider script
```

---

## Contributing

1. Fork the repository.
2. Create a feature branch: `git checkout -b my-new-feature`.
3. Commit your changes: `git commit -m 'Add some feature'`.
4. Push to the branch: `git push origin my-new-feature`.
5. Submit a pull request.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Author

Created by Damien Jeannerat. Feel free to reach out for collaboration or questions.

---

## Additional Notes

- This project is designed for educational purposes.
- To extend functionality, explore SuperCollider's [official documentation](https://doc.sccode.org/).
