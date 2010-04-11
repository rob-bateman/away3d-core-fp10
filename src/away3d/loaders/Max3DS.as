﻿package away3d.loaders{	import away3d.arcane;	import away3d.containers.*;	import away3d.core.base.*;	import away3d.core.math.Number3D;	import away3d.core.utils.*;	import away3d.loaders.data.*;	import away3d.loaders.utils.*;	import away3d.materials.*;		import flash.utils.*;	use namespace arcane;	    /**    * File loader for the 3DS file format.    */	public class Max3DS extends AbstractParser	{		/** @private */        arcane override function prepareData(data:*):void        {			max3ds = Cast.bytearray(data);			max3ds.endian = Endian.LITTLE_ENDIAN;						//first chunk is always the primary, so we simply read it and parse it			var chunk:Chunk3ds = new Chunk3ds();			readChunk(chunk);			parse3DS(chunk);						//build materials			buildMaterials();						//build the meshes			for each (_meshData in meshDataList)				buildMesh(_meshData, _container as ObjectContainer3D);        }        		/** An array of bytes from the 3ds files. */		private var max3ds:ByteArray;		private var _verticesDictionary:Dictionary;		private var _materialData:MaterialData;		private var _faceMaterial:Material;		private var _meshData:MeshData;		private var _geometryData:GeometryData;		private var _moveVector:Number3D = new Number3D();				//>----- Color Types --------------------------------------------------------				private const AMBIENT:String = "ambient";		private const DIFFUSE:String = "diffuse";		private const SPECULAR:String = "specular";				//>----- Main Chunks --------------------------------------------------------				//private const PRIMARY:int = 0x4D4D;		private const EDIT3DS:int = 0x3D3D;  // Start of our actual objects		private const KEYF3DS:int = 0xB000;  // Start of the keyframe information				//>----- General Chunks -----------------------------------------------------				//private const VERSION:int = 0x0002;		//private const MESH_VERSION:int = 0x3D3E;		//private const KFVERSION:int = 0x0005;		private const COLOR_F:int = 0x0010;		private const COLOR_RGB:int = 0x0011;		//private const LIN_COLOR_24:int = 0x0012;		//private const LIN_COLOR_F:int = 0x0013;		//private const INT_PERCENTAGE:int = 0x0030;		//private const FLOAT_PERC:int = 0x0031;		//private const MASTER_SCALE:int = 0x0100;		//private const IMAGE_FILE:int = 0x1100;		//private const AMBIENT_LIGHT:int = 0X2100;				//>----- Object Chunks -----------------------------------------------------				private const MESH:int = 0x4000;		private const MESH_OBJECT:int = 0x4100;		private const MESH_VERTICES:int = 0x4110;		//private const VERTEX_FLAGS:int = 0x4111;		private const MESH_FACES:int = 0x4120;		private const MESH_MATER:int = 0x4130;		private const MESH_TEX_VERT:int = 0x4140;		//private const MESH_XFMATRIX:int = 0x4160;		//private const MESH_COLOR_IND:int = 0x4165;		//private const MESH_TEX_INFO:int = 0x4170;		//private const HEIRARCHY:int = 0x4F00;				//>----- Material Chunks ---------------------------------------------------				private const MATERIAL:int = 0xAFFF;		private const MAT_NAME:int = 0xA000;		private const MAT_AMBIENT:int = 0xA010;		private const MAT_DIFFUSE:int = 0xA020;		private const MAT_SPECULAR:int = 0xA030;		//private const MAT_SHININESS:int = 0xA040;		//private const MAT_FALLOFF:int = 0xA052;		//private const MAT_EMISSIVE:int = 0xA080;		//private const MAT_SHADER:int = 0xA100;		private const MAT_TEXMAP:int = 0xA200;		private const MAT_TEXFLNM:int = 0xA300;		//private const OBJ_LIGHT:int = 0x4600;		//private const OBJ_CAMERA:int = 0x4700;				//>----- KeyFrames Chunks --------------------------------------------------				//private const ANIM_HEADER:int = 0xB00A;		//private const ANIM_OBJ:int = 0xB002;		//private const ANIM_NAME:int = 0xB010;		//private const ANIM_POS:int = 0xB020;		//private const ANIM_ROT:int = 0xB021;		//private const ANIM_SCALE:int = 0xB022;    	    	/**    	 * Array of mesh data objects used for storing the parsed 3ds data structure.    	 */		public var meshDataList:Array = [];				/**		 * Read id and length of 3ds chunk		 * 		 * @param chunk 		 * 		 */				private function readChunk(chunk:Chunk3ds):void		{			chunk.id = max3ds.readUnsignedShort();			chunk.length = max3ds.readUnsignedInt();			chunk.bytesRead = 6;		}				/**		 * Skips past a chunk. If we don't understand the meaning of a chunk id,		 * we just skip past it.		 * 		 * @param chunk		 * 		 */				private function skipChunk(chunk:Chunk3ds):void		{			max3ds.position += chunk.length - chunk.bytesRead;			chunk.bytesRead = chunk.length;		}				/**		 * Read the base 3DS object.		 * 		 * @param chunk		 * 		 */				private function parse3DS(chunk:Chunk3ds):void		{			while (chunk.bytesRead < chunk.length)			{				var subChunk:Chunk3ds = new Chunk3ds();				readChunk(subChunk);				switch (subChunk.id)				{					case EDIT3DS:						parseEdit3DS(subChunk);						break;					case KEYF3DS:						skipChunk(subChunk);						break;					default:						skipChunk(subChunk);				}				chunk.bytesRead += subChunk.length;			}		}				/**		 * Read the Edit chunk		 * 		 * @param chunk		 * 		 */		private function parseEdit3DS(chunk:Chunk3ds):void		{			while (chunk.bytesRead < chunk.length)			{				var subChunk:Chunk3ds = new Chunk3ds();				readChunk(subChunk);				switch (subChunk.id)				{					case MATERIAL:						parseMaterial(subChunk);						break;					case MESH:						_meshData = new MeshData();						readMeshName(subChunk);        				_meshData.geometry = _geometryLibrary.addGeometry(_meshData.name);        				_geometryData = _meshData.geometry;        				//TODO: get rid of _verticesDictionary        				_verticesDictionary = new Dictionary(true);						parseMesh(subChunk);						meshDataList.push(_meshData);						if (centerMeshes) {							_geometryData.maxX = -Infinity;							_geometryData.minX = Infinity;							_geometryData.maxY = -Infinity;							_geometryData.minY = Infinity;							_geometryData.maxZ = -Infinity;							_geometryData.minZ = Infinity;			                for each (var _vertex:Vertex in _verticesDictionary) {								if (_geometryData.maxX < _vertex._x)									_geometryData.maxX = _vertex._x;								if (_geometryData.minX > _vertex._x)									_geometryData.minX = _vertex._x;								if (_geometryData.maxY < _vertex._y)									_geometryData.maxY = _vertex._y;								if (_geometryData.minY > _vertex._y)									_geometryData.minY = _vertex._y;								if (_geometryData.maxZ < _vertex._z)									_geometryData.maxZ = _vertex._z;								if (_geometryData.minZ > _vertex._z)									_geometryData.minZ = _vertex._z;			                }						}						break;					default:						skipChunk(subChunk);				}								chunk.bytesRead += subChunk.length;			}		}				private function parseMaterial(chunk:Chunk3ds):void		{			while (chunk.bytesRead < chunk.length)			{				var subChunk:Chunk3ds = new Chunk3ds();				readChunk(subChunk);				switch (subChunk.id)				{					case MAT_NAME:						readMaterialName(subChunk);						break;					case MAT_AMBIENT:						readColor(AMBIENT);						break;					case MAT_DIFFUSE:						readColor(DIFFUSE);						break;					case MAT_SPECULAR:						readColor(SPECULAR);						break;					case MAT_TEXMAP:						parseMaterial(subChunk);						break;					case MAT_TEXFLNM:						readTextureFileName(subChunk);						break;					default:						skipChunk(subChunk);				}				chunk.bytesRead += subChunk.length;			}		}				private function readMaterialName(chunk:Chunk3ds):void		{			_materialData = _materialLibrary.addMaterial(readASCIIZString(max3ds));			_symbolLibrary[_materialData.name] = _materialData;			chunk.bytesRead = chunk.length;		}				private function readColor(type:String):void		{			_materialData.materialType = MaterialData.SHADING_MATERIAL;						var color:int;			var chunk:Chunk3ds = new Chunk3ds();			readChunk(chunk);			switch (chunk.id)			{				case COLOR_RGB:					color = readColorRGB(chunk);					break;				case COLOR_F:				// TODO: write implentation code					trace("COLOR_F not implemented yet");					skipChunk(chunk);					break;				default:					skipChunk(chunk);					trace("unknown ambient color format");			}						switch (type)			{				case AMBIENT:					_materialData.ambientColor = color;					break;				case DIFFUSE:					_materialData.diffuseColor = color;					break;				case SPECULAR:					_materialData.specularColor = color;					break;			}		}				private function readColorRGB(chunk:Chunk3ds):int		{			var color:int = 0;						for (var i:int = 0; i < 3; ++i)			{				var c:int = max3ds.readUnsignedByte();				color += c*Math.pow(0x100, 2-i);				chunk.bytesRead++;			}						return color;		}				private function readTextureFileName(chunk:Chunk3ds):void		{			_materialData.textureFileName = readASCIIZString(max3ds);			_materialData.materialType = MaterialData.TEXTURE_MATERIAL;						chunk.bytesRead = chunk.length;		}				private function parseMesh(chunk:Chunk3ds):void		{			while (chunk.bytesRead < chunk.length)			{				var subChunk:Chunk3ds = new Chunk3ds();				readChunk(subChunk);				switch (subChunk.id)				{					case MESH_OBJECT:						parseMesh(subChunk);						break;					case MESH_VERTICES:						readMeshVertices(subChunk);						break;					case MESH_FACES:						readMeshFaces(subChunk);						parseMesh(subChunk);						break;					case MESH_MATER:						readMeshMaterial(subChunk);						break;					case MESH_TEX_VERT:						readMeshTexVert(subChunk);						break;					default:						skipChunk(subChunk);				}				chunk.bytesRead += subChunk.length;			}		}				private function readMeshName(chunk:Chunk3ds):void		{			_meshData.name = readASCIIZString(max3ds);			chunk.bytesRead += _meshData.name.length + 1;						Debug.trace(" + Build Mesh : " + _meshData.name);		}				private function readMeshVertices(chunk:Chunk3ds):void		{			var numVerts:int = max3ds.readUnsignedShort();			chunk.bytesRead += 2;						for (var i:int = 0; i < numVerts; ++i)			{				_meshData.geometry.vertices.push(new Vertex(-max3ds.readFloat(), max3ds.readFloat(), max3ds.readFloat()));				chunk.bytesRead += 12;			}		}				private function readMeshFaces(chunk:Chunk3ds):void		{			var numFaces:int = max3ds.readUnsignedShort();			chunk.bytesRead += 2;			for (var i:int = 0; i < numFaces; ++i)			{				var _faceData:FaceData = new FaceData();								_faceData.uv0 = _faceData.v0 = max3ds.readUnsignedShort();				_faceData.uv1 = _faceData.v1 = max3ds.readUnsignedShort();				_faceData.uv2 = _faceData.v2 = max3ds.readUnsignedShort();				_verticesDictionary[_faceData.v0] = _geometryData.vertices[_faceData.v0];				_verticesDictionary[_faceData.v1] = _geometryData.vertices[_faceData.v1];				_verticesDictionary[_faceData.v2] = _geometryData.vertices[_faceData.v2];				_faceData.visible = (max3ds.readUnsignedShort() as Boolean);				chunk.bytesRead += 8;								_geometryData.faces.push(_faceData);			}		}					/**		 * Read the Mesh Material chunk		 * 		 * @param chunk		 * 		 */		private function readMeshMaterial(chunk:Chunk3ds):void		{			var meshMaterial:MeshMaterialData = new MeshMaterialData();			meshMaterial.symbol = readASCIIZString(max3ds);			chunk.bytesRead += meshMaterial.symbol.length +1;						var numFaces:int = max3ds.readUnsignedShort();			chunk.bytesRead += 2;			for (var i:int = 0; i < numFaces; ++i)			{				meshMaterial.faceList.push(max3ds.readUnsignedShort());				chunk.bytesRead += 2;			}						_meshData.geometry.materials.push(meshMaterial);		}				private function readMeshTexVert(chunk:Chunk3ds):void		{			var numUVs:int = max3ds.readUnsignedShort();			chunk.bytesRead += 2;						for (var i:int = 0; i < numUVs; ++i)			{				_meshData.geometry.uvs.push(new UV(max3ds.readFloat(), max3ds.readFloat()));				chunk.bytesRead += 8;			}		}				/**		 * Reads a null-terminated ascii string out of a byte array.		 * 		 * @param data The byte array to read from.		 * @return The string read, without the null-terminating character.		 * 		 */				private function readASCIIZString(data:ByteArray):String		{			//var readLength:int = 0; // length of string to read			var l:int = data.length - data.position;			var tempByteArray:ByteArray = new ByteArray();						for (var i:int = 0; i < l; ++i)			{				var c:int = data.readByte();								if (c == 0)				{					break;				}				tempByteArray.writeByte(c);			}						var asciiz:String = "";			tempByteArray.position = 0;			for (i = 0; i < tempByteArray.length; ++i)			{				asciiz += String.fromCharCode(tempByteArray.readByte());			}			return asciiz;		}				/** @private */        protected override function getFileType():String        {        	return "3ds";        }            	/**    	 * A scaling factor for all geometry in the model. Defaults to 1.    	 */        public var scaling:Number;        		/**		 * Creates a new <code>Max3DS</code> object. Not intended for direct use, use the static <code>parse</code> or <code>load</code> methods.		 * 		 * @param	data				The binary data of a loaded file.		 * @param	init	[optional]	An initialisation object for specifying default instance properties.		 * 		 * @see away3d.loaders.Max3DS#parse()		 * @see away3d.loaders.Max3DS#load()		 */		public function Max3DS(init:Object = null)		{			super(init);						scaling = ini.getNumber("scaling", 1);            			_container = new ObjectContainer3D(ini);			_container.name = "max3ds";						_container.materialLibrary = _materialLibrary;			_container.geometryLibrary = _geometryLibrary;						binary = true;		}		/**		 * Creates a 3d container object from the raw binary data of a 3ds file.		 * 		 * @param	data				The binary data of a loaded file.		 * @param	init	[optional]	An initialisation object for specifying default instance properties.		 * 		 * @return						A 3d container object representation of the 3ds file.		 */        public static function parse(data:*, init:Object = null):ObjectContainer3D        {        	return Loader3D.parse(data, Max3DS, init).handle as ObjectContainer3D;        }    	    	/**    	 * Loads and parses a 3ds file into a 3d container object.    	 *     	 * @param	url					The url location of the file to load.    	 * @param	init	[optional]	An initialisation object for specifying default instance properties.    	 *     	 * @return						A 3d loader object that can be used as a placeholder in a scene while the file is loading.    	 */        public static function load(url:String, init:Object = null):Loader3D        {            return Loader3D.load(url, Max3DS, init);        }	}}class Chunk3ds{		public var id:int;	public var length:int;	public var bytesRead:int;	 }