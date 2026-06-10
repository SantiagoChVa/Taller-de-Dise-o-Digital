data = open('programa.hex').read()

words = []
bytes_list = []

for line in data.splitlines():
    line = line.strip()

    if not line:
        continue

    if line.startswith('@'):
        continue

    bytes_list += line.split()

# Rellenar con 00 si la cantidad de bytes no es múltiplo de 4
padding = 0
while len(bytes_list) % 4 != 0:
    bytes_list.append('00')
    padding += 1

for i in range(0, len(bytes_list), 4):
    chunk = bytes_list[i:i+4]
    word = chunk[3] + chunk[2] + chunk[1] + chunk[0]
    words.append(word)

out = 'memory_initialization_radix=16;\n'
out += 'memory_initialization_vector=\n'
out += ',\n'.join(words) + ';'

open('programa.coe', 'w').write(out)

print('Listo! palabras generadas:', len(words))
print('Bytes usados:', len(bytes_list))
print('Padding agregado:', padding)
