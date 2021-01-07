from dataclasses import dataclass, field
from typing import Dict

@dataclass
class Block:
    hash: str
    labels: list = field(default_factory=str)
    value: list = field(default_factory=list)
    metadata: dict = field(default_factory=dict)
    children: dict = field(default_factory=dict)

    def getChild(self, hashPart):
        return self.children[hashPart]

    def insertChild(self, hashPart):
        if hashPart not in self.children:
            self.children[hashPart] = Block(
                hash=hashPart,
                labels=[],
                value=[]
            )

        return self.children[hashPart]

    def nodes(self, key=[]):
        yield (key, self)

        for hashPart, child in self.children.items():
            yield from child.nodes(key + [hashPart])

    def items(self):
        for key, node in self.nodes():
            if len(node.value) != 0:
                yield (key, node)

    def forks(self):
        for key, node in self.nodes():
            if len(node.children) > 1:
                yield (key, node)

@dataclass
class BestTipTrie:
    # Empty root node, for empty keys
    root: Block = field(default_factory=lambda: Block(hash=None, value=[]))
    blocks: Dict[str, Block] = field(default_factory=dict)

    def insertLink(self, parent: str, child: str, value=None):
        if parent in self.blocks:
            childNode = self.blocks[parent].insertChild(child)
            self.blocks[child] = childNode
            if value:
                childNode.value.append(value)
        elif child in self.blocks:
            # Save child node 
            childNode = self.root.children[child]
            # Delete it from the root's children
            del self.root.children[child]
            # Add the new parent as a child of the root
            parentNode = self.root.insertChild(parent)
            self.blocks[parent] = parentNode
            parentNode.children[childNode.hash] = childNode
            if value:
                childNode.value.append(value)
        else:
            self.insert([parent, child], value)

    def get(self, chain):
        node = self.root
        for hashPart in chain:
            node = node.getChild(hashPart)
        return node.value

    # TODO should not assume chain begins at the root, should learn to
    # splice the chain into the existing tree like insertLink
    # ([str], value)
    def insert(self, chain, label):
        if chain[-1] in self.blocks:
            node = self.blocks[chain[-1]]
        else:
            node = self.root
        for hashPart in chain:
            if hashPart in self.blocks:
                node = self.blocks[hashPart]
            node = node.insertChild(hashPart)
            self.blocks[hashPart] = node
        node.labels.append(label)

    def prefix(self):
        key = []
        node = self.root
        while len(node.children) == 1:
            keyPart = list(node.children.keys())[0]
            key.append(keyPart)
            node = node.children[keyPart]

        return key

    # ([str], [value])
    def items(self):
        yield from self.root.items()

    # ([str])
    def forks(self):
        yield from self.root.forks()
