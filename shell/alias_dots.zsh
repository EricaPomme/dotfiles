# Alias to change '..' to 'cd ..' and beyond.
# Change {2..x} to add more dots but 10 is probably already stupid :3

for i in {2..10}; do
    alias "$(printf '.%.0s' $(seq 1 $i))"="cd $(printf '../%.0s' $(seq 1 $i))"
done
