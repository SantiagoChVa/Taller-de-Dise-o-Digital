data = open('programa.hex').read()
words = []
bytes_list = []
for line in data.splitlines():
    if line.startswith('@'):
        continue
    bytes_list += line.strip().split()

for i in range(0, len(bytes_list), 4):
    chunk = bytes_list[i:i+4]
    word = chunk[3] + chunk[2] + chunk[1] + chunk[0]
    words.append(word)

out = 'memory_initialization_radix=16;\nmemory_initialization_vector=\n'
out += ',\n'.join(words) + ';'
open('programa.coe', 'w').write(out)
print('Listo! palabras generadas:', len(words))
